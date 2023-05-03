# (c) Copyright IBM Corp. 2023

class InstanaPadrinoApp < ::Padrino::Application
  get '/' do
    "Hello Padrino!"
  end
  
  get '/greet/:name' do
    "Hello, #{params[:name]}!"
  end
end

run InstanaPadrinoApp
