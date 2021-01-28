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
