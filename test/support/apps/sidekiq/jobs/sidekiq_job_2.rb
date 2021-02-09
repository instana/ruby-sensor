# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

class SidekiqJobTwo
  include Sidekiq::Worker

  def perform(a, b, c)
    raise 'Fail to execute the job'
  end
end
