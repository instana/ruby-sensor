module AgentTasks
  # When request(s) are received by the host agent, it is sent here
  # for handling & processing.
  #
  # @param json_string [String] the requests from the host agent
  #

  OJ_OPTIONS = {mode: :strict}

  def handle_agent_tasks(json_string)
    tasks = Oj.load(json_string, OJ_OPTIONS)

    if tasks.is_a?(Hash)
      process_agent_task(tasks)
    elsif tasks.is_a?(Array)
      tasks.each do |t|
        process_agent_task(t)
      end
    end
  end

  # Process a task sent from the host agent.
  #
  # @param task [String] the request json from the host agent
  #
  def process_agent_task(task)
    if task.key?("action")
      if task["action"] == "ruby.source"
        payload = ::Instana::Util.get_rb_source(task["args"]["file"])
      else
        payload = { :error => "Unrecognized action: #{task["action"]}. An newer Instana gem may be required for this. Current version: #{::Instana::VERSION}" }
      end
    else
      payload = { :error => "Instana Ruby: No action specified in request." }
    end

    path = "com.instana.plugin.ruby/response.#{@process[:report_pid]}?messageId=#{URI.encode(task['messageId'])}"
    uri = URI.parse("http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/#{path}")
    req = Net::HTTP::Post.new(uri)
    req.body = Oj.dump(payload, OJ_OPTIONS)
    ::Instana.logger.debug "Responding to agent request: #{req.inspect}"
    make_host_agent_request(req)

  rescue StandardError => e
    Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
    Instana.logger.debug e.backtrace.join("\r\n")
  end
end
