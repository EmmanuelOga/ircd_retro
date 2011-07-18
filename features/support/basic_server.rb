require 'logger'

# http://topfunky.net/svn/plugins/hodel_3000_compliant_logger/lib/hodel_3000_compliant_logger.rb
class MyLogger < Logger
  def format_message(severity, timestamp, progname, msg)
    "#{severity}: #{msg2str(msg).gsub(/\n/, '').lstrip}\n"
  end

  def msg2str(msg)
    case msg
    when ::String then msg
    when ::Exception then "#{ msg.message } (#{ msg.class }): " << (msg.backtrace || []).join(" | ")
    else
      msg.inspect
    end
  end
end

class BasicServer
  def self.start
    server = IRCDSlim::Server.new do |server|
      server.prefix = `hostname`.chomp
      server.date = Time.now
      server.motd = "Welcome!"
      server.port = $ircd_port || 10000
      server.logger = MyLogger.new "log/development.log"
    end

    trap("INT") do
      server.stop do
        EventMachine.stop
      end
    end

    EventMachine.run do
      $stderr.puts "Starting server at localhost:#{server.port}"
      server.start
      IRCDRetro::Base.new(server).start
    end
  end
end

