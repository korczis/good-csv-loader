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
      {'bucket': 'gcl-data'}, 
      ['starts-with', '$key', 'space-test/#{uuid}'],
      {'acl': 'private'},
      {'success_action_redirect': 'https://s3.amazonaws.com/gcl-data/upload-success.html'},
      ['starts-with', '$Content-Type', ''],
      ['content-length-range', 0, 1073741824]
    ]
  }"
end

aws_secret_key = 'Z56zbD0F/vR88iGN56DnGcOoagadSmKRsjOTHP/e'

S3_ENDPOINT = "https://gcl-data/"
PROJECT_CREATION_TOKEN = ENV['project_token']
GD_LOGIN = ENV['gd_login']
GD_PASS = ENV['gd_pass']

# Set public folder
set :public_folder, 'public'

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
        aws_secret_key, policy)
    ).gsub("\n","")

  project_prefix = S3_ENDPOINT + uuid
  content_type :json
  {
    :id => uuid,
    :upload_files_uri => project_prefix,
    :upload_policy => policy,
    :upload_signature => signature
  }.to_json
end

put '/publications/:id' do
  uuid = params[:id]

  spec = MultiJson.load(open("https://gist.githubusercontent.com/fluke777/10414368/raw/ada044a871f19449ccdd60af9637dede76ae2dd0/json_model.json") {|f| f.read}, :symbolize_keys => true)
  model = GoodData::Model::ProjectBlueprint.from_json(spec)

  # Doing some stuff
  begin
    GoodData.logging_on
    GoodData.connect(GD_LOGIN, GD_PASS)

    project = GoodData::Model::ProjectCreator.migrate(:spec => model, :token => PROJECT_CREATION_TOKEN)
    content_type :json
    {
      :project_uri => project.browser_uri
    }.to_json
  rescue
    halt 500
  end
end


post '/file_upload' do
  pp params["filename"]
  #pp params["body"]["filename"]
end
