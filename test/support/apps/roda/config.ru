# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

class InstanaRodaApp < Roda
  route do |r|
	  r.root do
	    r.redirect '/hello'
	  end
	  r.get "hello" do
	    "Hello Roda + Instana"
	  end
	  r.get "greet", String do |name|
	    "Hello, #{name}!"
	  end
  end
end

run InstanaRodaApp.freeze.app
