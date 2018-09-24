module AgentHooks
  # Used post fork to re-initialize state and restart communications with
  # the host agent.
  #
  def after_fork
    ::Instana.logger.debug "after_fork hook called. Falling back to unannounced state and spawning a new background agent thread."

    # Reseed the random number generator for this
    # new thread.
    srand

    transition_to(:unannounced)

    setup
    spawn_background_thread
  end

  def before_resque_fork
    ::Instana.logger.debug "before_resque_fork hook called. pid/ppid: #{Process.pid}/#{Process.ppid}"
    @is_resque_worker = true
  end

  def after_resque_fork
    ::Instana.logger.debug "after_resque_fork hook called. pid/ppid: #{Process.pid}/#{Process.ppid}"

    # Reseed the random number generator for this
    # new thread.
    srand

    ::Instana.config[:metrics][:enabled] = false

    @process[:pid] = Process.pid

    setup
    spawn_background_thread
  end
end
