# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

class MockTimer
  attr_reader :opts, :block, :running

  def initialize(*args, &blk)
    @opts = args.first
    @block = blk
    @running = false
  end

  def shutdown
    @running = false
  end

  def execute
    @running = true
  end
end
