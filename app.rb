#! /usr/bin/env ruby

require "bundler/setup"
require "sinatra"

# Set public folder
set :public_folder, 'public'

# Server root asset
get '/' do
  redirect '/index.html'
end
