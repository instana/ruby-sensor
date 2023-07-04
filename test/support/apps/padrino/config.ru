# (c) Copyright IBM Corp. 2023

require 'padrino'

class InstanaPadrinoApp < ::Padrino::Application
  enable :sessions

  get '/' do
    "Hello Padrino!"
  end

  get '/greet/:name' do
    "Hello, #{params[:name]}!"
  end
end

::Padrino.mount('InstanaPadrinoApp::App', :app_class => "InstanaPadrinoApp").to('/')

run ::Padrino.application
