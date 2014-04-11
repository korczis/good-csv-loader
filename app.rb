#! /usr/bin/env ruby

require "bundler/setup"
require "sinatra"
require "securerandom"
require "gooddata"
require "open-uri"
require "pry"
require "aws-sdk"
require "yaml"
require 'fileutils'

#S3 upload req's
require 'base64'
require 'openssl'
require 'digest/sha1'

def policy_document(date,uuid)
  return "
  {'expiration': '#{date}',
    'conditions': [ 
      {'bucket': '#{S3_BUCKET}'}, 
      ['starts-with', '$key', '#{uuid}/'],
      {'acl': 'private'},
      ['starts-with', '$Content-Type', ''],
      ['content-length-range', 0, 1073741824]
    ]
  }"
end

AWS_SECRET_KEY = 'Z56zbD0F/vR88iGN56DnGcOoagadSmKRsjOTHP/e'

S3_BUCKET = "gcl-data"
S3_ENDPOINT = "https://s3.amazonaws.com/#{S3_BUCKET}"
PROJECT_CREATION_TOKEN = ENV['project_token']
GD_LOGIN = ENV['gd_login']
GD_PASS = ENV['gd_pass']
FAYE_CLIENT = Faye::Client.new("http://localhost:9292/faye")

class SinatraApp < Sinatra::Base
	before do
			response.headers["Access-Control-Allow-Origin"] = "*"
			response.headers["Access-Control-Allow-Methods"] = "POST"
	end

  # Set public folder
  set :public_folder, 'public'
  set :logging, true

  Faye.logger = Logger.new(STDOUT)



  # Server root asset
  get '/' do
    redirect '/index.html'
  end

  post '/projects' do
    uuid = SecureRandom::uuid
    policy = Base64.encode64(policy_document("2016-01-01T00:00:00Z",uuid)).gsub("\n","")
    signature = Base64.encode64(
      OpenSSL::HMAC.digest(
          OpenSSL::Digest::Digest.new('sha1'), 
          AWS_SECRET_KEY, policy)
      ).gsub("\n","")

    project_prefix = S3_ENDPOINT + uuid
    content_type :json
    {
      :id => uuid,
      :url => S3_ENDPOINT,
			:prefix => uuid,
      :policy => policy,
      :signature => signature
    }.to_json
  end

  post "/add_file" do
    FAYE_CLIENT.publish('/foo', {
      :file_added => {
        :filename => "x"
      }
    }.to_json)
  end

  post '/file_upload/:id' do
    id = params[:id]
    filename = params["filename"]
    FAYE_CLIENT.publish("/#{id}", {
      :file_added => {
        :filename => filename
      }
    }.to_json)
  end

  post '/file_columns/:id' do
    id = params[:id]
    filename = params["filename"]
    columns = params["columns"]
    FAYE_CLIENT.publish("/#{id}", {
      :file_inspected => {
        :filename => filename,
        :columns => columns
      }
    }.to_json)
  end

  post "/add_columns" do
    FAYE_CLIENT.publish('/foo', {
      :file_inspected => {
        :filename => "x",
        :columns => [
          {
            :name => "Id"
          },
          {
            :name => "Name"
          }]
      }
    }.to_json)
  end

  put '/publications/:id' do
    uuid = params[:id]
    FileUtils::mkdir_p "temp/#{uuid}/"

    AWS.config(YAML.load_file("config.yml"))
    s3 = AWS::S3.new()
    stage_bucket = s3.buckets["gcl-data-stage"]

    spec = MultiJson.load(open("https://gist.githubusercontent.com/adriantoman/239655ae32e7c23ad332/raw/60dc2f82581a6c207db93f07607ef4104f33df23/gistfile1.txt") {|f| f.read}, :symbolize_keys => true)
    model = GoodData::Model::ProjectBlueprint.from_json(spec)
    begin
      GD_LOGIN = ENV['gd_login']
      GD_PASS = ENV['gd_pass']

      GoodData.logging_on
      GoodData.connect(GD_LOGIN, GD_PASS,{:webdav_server => "https://na1-di.gooddata.com"})

      project = GoodData::Model::ProjectCreator.migrate(:spec => model, :token => PROJECT_CREATION_TOKEN)

      FAYE_CLIENT.publish("/#{uuid}", {
          :status => {
              :message => "The model created. Starting download from S3"
          }
      }.to_json)

      GoodData.use project
      files_data = []

      spec[:datasets].each do |ds|
        filename = ds[:filename].split("/").last
        File.open("temp/#{uuid}/#{filename}", 'wb') do |file|
          stage_bucket.objects[ds[:filename]].read do |chunk|
            file.write(chunk)
          end
        end
        schema =  model.datasets.find{|s| s.name == ds[:name] }

        FAYE_CLIENT.publish("/#{uuid}", {
            :status => {
                :message => "Donwload of dataset #{ds[:name]} finished, starting upload to GoodData"
            }
        }.to_json)

        schema.upload("temp/" + ds[:filename],:project => project)

        FAYE_CLIENT.publish("/#{uuid}", {
            :status => {
                :message => "Upload of dataset #{ds[:name]} to GoodData has finished!"
            }
        }.to_json)
      end

      #users_data = [["id", "name"], ["1", "Tomas"]]
      #regions_data = [["id", "name"], ["1", "US"]]
      #oppty_data = [["amount", "closed_date", "user_id", "region_id"], [1, "1/1/2010", "1", "1"]]

      #model.datasets.zip(files_data).each do |ds, data|
      #  ds.upload(data, :project => project)
      #end


      #GoodData.with_project(project) do |p|
      #  reports = model.suggest_reports
      #  reports.each { |r| r.save };
      #end

      request = {
          "invitations" =>
              [{
                   "invitation" => {
                       "content"=> {
                           "email"=> "svarovsky@gooddata.com",
                           "role"=> "/gdc/projects/#{project.pid}/roles/2",
                           "firstname"=> "GoodData",
                           "lastname"=> "",
                           "action"=> {
                               "setMessage"=> "Welcome to your new project"
                           }
                       }
                   }
               }]
      }
      GoodData.post("/gdc/projects/#{project.pid}/invitations", request)

      FAYE_CLIENT.publish("/#{uuid}", {
          :status => {
              :message => "Project is ready!",
              :url => project.browser_uri
          }
      }.to_json)


      content_type :json
      {
        :project_uri => project.browser_uri
      }.to_json

    rescue => e
      halt 500
    end
  end
end
