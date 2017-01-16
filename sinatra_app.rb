require 'sinatra'
set port: 9494
set bind: '0.0.0.0'

get '/api8/foo' do
  'hello from sinatra'
end
