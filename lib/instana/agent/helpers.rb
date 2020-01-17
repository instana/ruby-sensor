module AgentHelpers
  # Indicates whether we are running in a pid namespace (such as
  # Docker).
  #
  def pid_namespace?
    return false unless @is_linux
    Process.pid != get_real_pid
  end

  # Attempts to determine if we're running inside a container.
  # The qualifications are:
  #   1. Linux based OS
  #   2. /proc/self/cpuset exists and contents include a container id
  def running_in_container?
    return false unless @is_linux

    cpuset_contents = get_cpuset_contents

    if cpuset_contents.nil? or cpuset_contents == '/'
      ::Instana.logger.debug "running_in_container? == no"
      return false
    end
    ::Instana.logger.debug "running_in_container? == yes"
    true
  end

  # Attempts to determine the true process ID by querying the
  # /proc/<pid>/sched file.  This works on linux currently.
  #
  def get_sched_pid
    sched_file = "/proc/self/sched"
    pid = Process.pid

    if File.exist?(sched_file)
      v = File.open(sched_file, &:readline)
      pid = v.match(/\d+/).to_s.to_i
    end
    pid
  end

  # Open and read /proc/<pid>/cpuset and return as a string.  Used as
  # part of the announce payload for process differentiation.
  #
  def get_cpuset_contents
    cpuset_file = "/proc/#{Process.pid}/cpuset"
    contents = ""

    if File.exist?(cpuset_file)
      contents = File.open(cpuset_file, "r").read
    end
    contents.chomp
  rescue Exception => e
    Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
    return nil
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
    return true if ENV.key?('INSTANA_TEST')

    # Occasionally Run Fork detection
    if rand(10) > 8
      if !@is_resque_worker && (@process[:pid] != Process.pid)
        ::Instana.logger.debug "Instana: detected fork. (this pid: #{Process.pid}/#{Process.ppid})  Calling after_fork"
        after_fork
      end
    end

    @state == :ready || @state == :announced
  rescue => e
    Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
    Instana.logger.debug { e.backtrace.join("\r\n") } unless ENV.key?('INSTANA_TEST')
    return false
  end
end
