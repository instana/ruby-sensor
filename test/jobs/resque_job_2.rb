class ResqueWorkerJob2
  @queue = :normal

  def self.perform(*args)
    raise "Fake exception"
  end
end
