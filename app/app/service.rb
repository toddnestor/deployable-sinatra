# coding: utf-8
# frozen_string_literal: true

require 'sinatra/base'

module Pluto
  class Service < Sinatra::Base
    require 'sinatra/reloader' if development?

    get '/' do
      '🎉🤑💸💰'
    end
  end
end
