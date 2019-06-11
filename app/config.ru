# frozen_string_literal: true

require 'bundler/setup'
require_relative 'app/service'

Pluto::Service.set :root, ::File.dirname(__FILE__)

Pluto::Service.configure do
  Pluto::Service.enable :logging
  file = File.new("#{Pluto::Service.settings.root}/log/#{Pluto::Service.settings.environment}.log", 'a+')
  file.sync = true
  use Rack::CommonLogger, file
end

run Pluto::Service
