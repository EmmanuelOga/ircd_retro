$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), "../../ircd_slim/lib"))

require 'firering'
require 'ircd_slim'
require 'digest/md5'

module IRCDRetro
  VERSION = "0.0.1"

  class Base < Struct.new(:ircd)
    ROOM = "#retro"
    NICK = "scrummaster"
    TOPIC = "Welcome to a new retrospective! Type .help to get ... help."

    # Each msg detected as a command executes the associated method.
    COMMANDS = {
      /.timer (\d+)/  => :timer,
      /.bstorm/       => :brainstorm,
      /.endstorm/     => :endstorm,
      /.list/         => :list,
      /.merge (.+)/   => :merge,
      /.voters (\d+)/ => :voters,
      /.results/      => :results,
      /.help/         => :help
    }

    def nicks
      ircd.clients.nicks.delete_if { |n| n == NICK }
    end

    def start
      @bs = BrainStorm.new(0)

      @chan = ircd.channels[ROOM]
      @chan.release_if_empty = false
      @chan.change_topic(TOPIC)

      @master = IRCDSlim::Client.new(NICK, NICK, `hostname`.chomp, ircd.port, NICK, "127.0.0.1")

      @chan.subscribe(@master)

      # hook to the channel's events, look for messages not coming from the scrummaster (this script).
      @sid = @chan.watch(:only => [:priv_msg, :notice], :not_from => [@master]) do |ircd_message|
        ircd_message.body.each_line do |text|
          command = COMMANDS.detect { |match, meth| text =~ match }
          if command
            send(command.last, *Regexp.last_match.to_a[1..-1])
          elsif text =~ /^\./
            speak("Sorry, there is no command #{text.inspect}. Type =help to see available commands.")
          else
            handle(text, ircd_message.client.nick)
          end
        end
      end
    end

    module Output
      require 'shellwords'

      def figlet(text)
        `echo #{text.to_s.shellescape} | figlet`.chomp.each_line { |chunk| speak(chunk.chomp) }
      end

      def speak(what)
        @chan.priv_msg(@master, what)
      end

      def line
        speak("==" * 40)
      end
    end

    include Output

    def help(*)
      speak("Available commands: ")
      COMMANDS.each { |match, meth| speak(match.inspect[1..-2]) }
    end

    def timer(minutes)
      speak("#{nicks.join(", ")}: setting a timer of #{minutes} minutes.")
      Timer.new(minutes) do |t|
        t.on_finish { line; speak("#{nicks.join(", ")}: Time is Off!!"); line }
        t.on_notice { |elapsed, left| speak("TIMER: #{elapsed} minutes elapsed, #{left} minutes to go.") }
      end
    end

    def brainstorm(*)
      @bs.start(nicks.length)
      speak("Starting BrainStorm session for [[[ #{@bs.voters} ]]] participants.")
      speak("Prefix your items with *, send .endstorm to finish."); line
    end

    def voters(count)
      speak("Adjusting voters to #{count.to_i}.")
      @bs.voters = count.to_i
    end

    def endstorm(*)
      list
      speak("Finished retrieving Items. Send .list to see the list.")
      speak("To vote, enter your selection like this: 'votes:id1,id2,id3'"); line
      @bs.stop
    end

    def list(*)
      line; speak("Items Retrieved:"); line
      @bs.items.each_with_index { |item, index| speak("[[[ #{index} ]]] #{item}") if item }
      line
    end

    def merge(selection)
      votes = selection.split(/\s*,\s*/).map(&:to_i)
      @bs.merge(votes)
      speak("Done merging #{votes.inspect}."); list
    rescue => e
      ircd.logger.error(e)
      speak("Sorry, #{selection.inspect} is not a proper comma separated list of numbers.")
    end

    def handle(input, nick)
      if @bs.running?
        @bs << $1 if input =~ /^\s*\*\s*(.+)/

      elsif input =~ /^votes:(.+)/
        @bs.vote(nick, $1.split(",").map(&:strip).map(&:to_i))

        if @bs.votation_complete?
          figlet("Votation Done")
          results
        end
      end

    rescue => e
      ircd.logger.error(e)
      speak("#{nick}: #{e.message}")
    end

    def results(*)
      if @bs.votation_complete?
        @bs.result.each do |idx, count, item|
          figlet(count)
          speak("With #{count} votes: Item ##{idx}")
          speak(item)
          line
        end
      else
        speak("Please wait for all the participants to vote #{nicks.join(", ")}.")
        speak(@bs.votes.inspect)
      end
    end
  end

  class Timer
    def on_finish(&block); @on_finish = block; end
    def on_notice(&block); @on_notice = block; end
    def initialize(minutes)
      yield self
      seconds, limit = 0, minutes.to_f * 60
      timer = EventMachine::PeriodicTimer.new(30) do
        seconds += 30
        if seconds >= limit
          @on_finish.call; timer.cancel
        else
          @on_notice.call(seconds / 60.0, (limit - seconds) / 60.0)
        end
      end
    end
  end

  class BrainStorm
    attr_reader :votes, :items
    attr_accessor :voters

    def start(voters)
      @votes, @items, @running, @voters = {}, [], true, voters.to_i
    end

    def running?
      @running
    end

    def stop
      @running = false
    end

    def << (items)
      items.each_line { |item| @items.push(item) }
    end

    def vote(nick, user_votes)
      if items.nil? || items.empty? then raise "No items to vote yet."
      elsif user_votes.length < 3 then raise "Please vote 3 items."
      elsif user_votes.detect { |i| items[i].nil? } then raise "Make sure you all your votes exist on the list."
      else
        votes[nick] = user_votes
      end
    end

    def votation_complete?
      votes.length >= voters
    end

    def result
      votes = @votes.values.flatten.inject(Hash.new(0)) { |hash, vote| hash[vote] += 1; hash }
      votes.sort { |a, b| b.last <=> a.last }.map { |idx, count, item| [idx, count, @items[idx]] }
    end

    def merge(indexes)
      return if indexes.length < 2
      sources = []
      items.each_with_index { |item, idx| sources << idx if item && indexes.include?(idx) }
      return if sources.length < 2
      merged = []
      sources.each { |idx| merged << items[idx]; items[idx] = nil }
      items.push(merged.join(" / ").gsub("\n", ". ").chomp) if merged.length > 1
    end
  end
end
