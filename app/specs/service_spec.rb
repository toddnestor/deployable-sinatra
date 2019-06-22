require File.expand_path('../test_helper.rb', __FILE__)
require 'pry'

describe '/healthcheck' do
  before do
    get '/healthcheck'
  end

  it 'returns a successful response' do
    assert last_response.ok?
  end

  it 'returns healthy' do
    assert_equal 'healthy', last_response.body
  end
end
