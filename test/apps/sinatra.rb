class InstanaSinatraApp < ::Sinatra::Base
  get '/' do
    "Hello Sinatra!"
  end
  
  get '/greet/:name' do
    "Hello, #{params[:name]}!"
  end
end
