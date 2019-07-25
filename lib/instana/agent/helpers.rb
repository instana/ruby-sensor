module AgentHelpers
  # Indicates whether we are running in a pid namespace (such as
  # Docker).
  #
  def pid_namespace?
    return false unless @is_linux
    Process.pid != get_real_pid
  end

  # Attempts to determine the true process ID by querying the
  # /proc/<pid>/sched file.  This works on linux currently.
  #
  def get_real_pid
    raise RuntimeError.new("Unsupported platform: get_real_pid") unless @is_linux

    sched_file = "/proc/#{Process.pid}/sched"
    pid = Process.pid

    if File.exist?(sched_file)
      v = File.open(sched_file, &:readline)
      pid = v.match(/\d+/).to_s.to_i
    end
    pid
  end

  # Returns the PID that we are reporting to
  #
  def report_pid
    @process[:report_pid]
  end

  # Determine whether the pid has changed since Agent start.
  #
  # @ return [Boolean] true or false to indicate if forked
  #
  def forked?
    @process[:pid] != Process.pid
  end

  # Indicates if the agent is ready to send metrics
  # and/or data.
  #
  def ready?
    # In test, we're always ready :-)
    return true if ENV['INSTANA_TEST']

    if !@is_resque_worker && forked?
      ::Instana.logger.debug "Instana: detected fork. (this pid: #{Process.pid}/#{Process.ppid})  Calling after_fork"
      after_fork
    end

    @state == :announced
  rescue => e
    Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
    Instana.logger.debug e.backtrace.join("\r\n") unless ENV.key?('INSTANA_TEST')
    return false
  end
end
