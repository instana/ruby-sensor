# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

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

run Cuba
