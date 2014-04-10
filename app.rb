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
