require 'bundler/setup'
require 'faye'

Faye::WebSocket.load_adapter('thin')
require File.expand_path('../app', __FILE__)

use Faye::RackAdapter, :mount      => '/faye',
                       :timeout    => 25
                       # ,
                       # :extensions => [MyExtension.new]

# use Rack::Static, :urls => ["/css", "/images"], :root => "public"
run Sinatra::Application

# require 'faye'
# Faye::WebSocket.load_adapter('thin')
# 
# app = Faye::RackAdapter.new(:mount => '/faye', :timeout => 25)
# 
# run app
