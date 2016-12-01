class InstanaRodaApp < Roda
  route do |r|
    r.root do
      r.redirect '/hello'
    end
    r.get "hello" do
      "Hello Roda + Instana"
    end
  end
end
