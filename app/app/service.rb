# coding: utf-8
# frozen_string_literal: true

require 'sinatra/base'

module App
  class Service < Sinatra::Base
    get '/' do
      "🎉🎉🎉 I REALLY AM DEVELOP!!! #{ENV['THIS_BE_REAL']}"
    end

    get '/healthcheck' do
      [200, 'healthy']
    end
  end
end
