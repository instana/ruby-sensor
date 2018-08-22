module Instana
  AUTOLOAD_DIRECTORIES = [:instrumentation, :frameworks].freeze
end


if !ENV.key?('INSTANA_DISABLE_AUTO_INSTR')
  #
  # Load all of the files in the specified subdirectories
  #
  ::Instana::AUTOLOAD_DIRECTORIES.each do |d|
    pattern = File.join(File.dirname(__FILE__), d.to_s, '*.rb')
    Dir.glob(pattern) do |f|
      begin
        require f
      rescue => e
        Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end
