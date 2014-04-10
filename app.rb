#! /usr/bin/env ruby

require "bundler/setup"
require "sinatra"
require "securerandom"

S3_ENDPOINT = "https://some_uri_here/"

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

  content_type :json
  # Doing some stuff
  sleep 1
  
  # if ok
  content_type :json
  status 201
  {
    :project_uri => "https://secure.gooddata.com/gdc/projects/#{uuid}"
  }.to_json
end
