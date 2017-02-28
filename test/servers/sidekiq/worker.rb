require 'sidekiq/cli'

options = []
options << ["-r", Dir.pwd + "/test/servers/sidekiq/initializer.rb"]
options << ["-q default -q low -q important"]
options << ["-c 4"]
options << ["-P", Dir.pwd + "/test/tmp/sidekiq_#{Process.pid}.pid"]

cmd_line = ""
options.flatten.each do |x|
  cmd_line += " #{x}"
end

::Instana.logger.warn "Booting background Sidekiq worker..."

Thread.new do
  begin
    system("INSTANA_GEM_TEST=true sidekiq #{cmd_line}")
  ensure
    # Get and send a kill signal to the sidekiq process
    s = File.read(Dir.pwd + "/test/tmp/sidekiq_#{Process.pid}.pid")
    Process.kill("QUIT", s.chop.to_i)
  end
end

sleep 7
