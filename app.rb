#! /usr/bin/env ruby

require "bundler/setup"
require "sinatra"
require "securerandom"
require "gooddata"
require "open-uri"
require "pry"

S3_ENDPOINT = "https://some_uri_here/"
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
  content_type :json
  {
    :id => uuid,
    :upload_files_uri => S3_ENDPOINT + uuid
  }.to_json
end

put '/publications/:id' do
  uuid = params[:id]

  spec = MultiJson.load(open("https://gist.githubusercontent.com/fluke777/10414368/raw/ada044a871f19449ccdd60af9637dede76ae2dd0/json_model.json") {|f| f.read}, :symbolize_keys => true)
  model = GoodData::Model::ProjectBlueprint.from_json(spec)

  # Doing some stuff
  begin
    GoodData.logging_on
    binding.pry
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
