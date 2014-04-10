require 'bundler/setup'
require 'faye'

require File.expand_path('../app', __FILE__)

use Faye::RackAdapter, :mount      => '/faye',
                       :timeout    => 25
                       # ,
                       # :extensions => [MyExtension.new]

use Rack::Static, :urls => ["/css", "/images"], :root => "public"
run Sinatra::Application