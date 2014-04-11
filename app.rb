#! /usr/bin/env ruby

require "bundler/setup"
require "sinatra"
require "securerandom"
require "gooddata"
require "open-uri"
require "pry"

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
			#response.headers["Access-Control-Allow-Methods"] = "GET, POST"
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

    url = S3_ENDPOINT
    content_type :json
    {
      :url => url,
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

    spec = MultiJson.load(open("https://gist.githubusercontent.com/fluke777/10414368/raw/ada044a871f19449ccdd60af9637dede76ae2dd0/json_model.json") {|f| f.read}, :symbolize_keys => true)
    model = GoodData::Model::ProjectBlueprint.from_json(spec)
    begin
      GoodData.logging_on
      GoodData.connect(GD_LOGIN, GD_PASS)
      project = GoodData::Model::ProjectCreator.migrate(:spec => model, :token => PROJECT_CREATION_TOKEN)

      users_data = [["id", "name"], ["1", "Tomas"]]
      regions_data = [["id", "name"], ["1", "US"]]
      oppty_data = [["amount", "closed_date", "user_id", "region_id"], [1, "1/1/2010", "1", "1"]]

      model.datasets.zip([users_data, regions_data, oppty_data]).each do |ds, data|
        ds.upload(data, :project => project)
      end

      GoodData.with_project(project) do |p|
        reports = model.suggest_reports
        reports.each { |r| r.save };
      end


      content_type :json
      {
        :project_uri => project.browser_uri
      }.to_json

    rescue
      halt 500
    end
  end
end
