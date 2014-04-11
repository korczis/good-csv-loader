require 'bundler/setup'
require 'faye'

Faye::WebSocket.load_adapter('thin')
require File.expand_path('../app', __FILE__)

use Faye::RackAdapter, :mount      => '/faye',
                       :timeout    => 25

use Rack::Static, :urls => ["/css", "/images"], :root => "public"
run SinatraApp
