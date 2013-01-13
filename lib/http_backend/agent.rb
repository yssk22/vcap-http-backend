require 'open3'
require 'yajl'
require 'vcap/common'

module VCAP::HttpBackend
  class Agent
    attr_reader :name, :domain, :host, :port,
                :monitor_interval, :listen_delay,
                :pid_filename, :auto_start, :start_command, :stop_on_exit, :stop_command

    def initialize(config)
      @monitor_interval = config["monitor_interval"] || 30
      @listen_delay     = config["listen_delay"] || 30
      @name             = config["name"]
      @domain           = config["domain"]
      @host             = config["host"]
      @port             = config["port"]
      @pid_filename     = config["pid_filename"]
      @auto_start       = config["auto_start"]
      @stop_on_exit     = config["stop_on_exit"]
      @start_command    = config["start"]
      @stop_command     = config["stop"]
      @checking = false
      @backend_alive = false
      @register_msg = Yajl::Encoder.encode({:host => @host, :port => @port, :uri => @domain, :tags => {:component => "HttpBackend-#{name}"} })
    end

    def start
      check
      NATS.subscribe('router.start') do
        if @backend_alive
          NATS.publish('router.register', @register_msg)
        end
      end
    end

    def check
      return if @checking
      @checking = true
      unless process_exists?
        if @backend_alive # status changed
          NATS.publish('router.unregister', @register_msg)
        end
        @backend_alive = false
        if @auto_start && @start_command
          logger.warn("Backend `#{name}` does not exist, try to start by `#{@start_command}`")
          stdout, stderr, status = Open3.capture3(@start_command)
          logger.warn("start result", {
            :stdout => stdout, :stderr => stderr, :status => status
          })
          logger.debug("waiting #{@listen_delay} seconds for #{@name} listening.")
          return EM.add_timer(@listen_delay) do
            @checking = false
            check
          end
        else
          logger.warn("Backend '#{name}' does not exist (auto_start = #{@auto_start})")
        end
      else
        unless @backend_alive # status changed
          NATS.publish('router.unregister', @register_msg)
        end
        @backend_alive = true
      end

      logger.debug("wait for #{@monitor_interval} seconds ... ")
      EM.add_timer(@monitor_interval) do
          @checking = false
          check
      end
    end

    def stop
    end

    protected

    def process_exists?
      if File.exist?(@pid_filename)
        pid = File.read(@pid_filename).to_i rescue 0
        if pid > 0
          begin
            Process.getpgid(pid)
            true
          rescue Errno::ESRCH
            logger.warn("Backend #{name} pidfile exists(#{pid}) but such process isnot found.")
            false
          end
        else
          false
        end
      else
        false
      end
    end

    def logger
      @logger ||= Steno.logger('hb.agent')
    end
  end
end