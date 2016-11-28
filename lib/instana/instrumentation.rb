#
# Load all of the files in the instrumentation subdirectory
#
pattern = File.join(File.dirname(__FILE__), 'instrumentation', '*.rb')
Dir.glob(pattern) do |f|
  begin
    require f
  rescue => e
    Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
    Instana.logger.debug e.backtrace.join("\r\n")
  end
end

#
# Load all of the files in the frameworks subdirectory
#
pattern = File.join(File.dirname(__FILE__), 'frameworks', '*.rb')
Dir.glob(pattern) do |f|
  begin
    require f
  rescue => e
    Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
    Instana.logger.debug e.backtrace.join("\r\n")
  end
end
