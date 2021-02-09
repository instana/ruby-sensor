# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

class InstanaSinatraApp < ::Sinatra::Base
  get '/' do
    "Hello Sinatra!"
  end
  
  get '/greet/:name' do
    "Hello, #{params[:name]}!"
  end
end

run InstanaSinatraApp
