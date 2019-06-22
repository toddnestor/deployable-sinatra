# frozen_string_literal: true

require 'bundler/setup'
require_relative 'app/service'

App::Service.set :root, ::File.dirname(__FILE__)

App::Service.configure do
  App::Service.enable :logging
  file = File.new("#{App::Service.settings.root}/log/#{App::Service.settings.environment}.log", 'a+')
  file.sync = true
  use Rack::CommonLogger, file
end

run App::Service
