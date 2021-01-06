require "cuba/safe"

Cuba.plugin ::Cuba::Safe

Cuba.define do
  on get do
    on "hello" do
      res.write "Hello Instana!"
    end
    
    on "greet/:name" do |name|
      res.write "Hello, #{name}"
    end

    on root do
      res.redirect '/hello'
    end
  end
end
