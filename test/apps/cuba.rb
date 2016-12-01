require "cuba/safe"

Cuba.plugin ::Cuba::Safe

Cuba.define do
  on get do
    on "hello" do
      res.write "Hello Instana!"
    end

    on root do
      res.redirect '/hello'
    end
  end
end
