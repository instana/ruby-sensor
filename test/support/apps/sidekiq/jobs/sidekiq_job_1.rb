# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

class SidekiqJobOne
  include Sidekiq::Worker

  def perform(a, b, c)
  end
end
