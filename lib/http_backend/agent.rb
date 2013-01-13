require 'open3'
require 'yajl'
require 'time'
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
      @checking      = false
      @is_backend_alive = false
      @keep_checking = false
      @last_check    = nil
      @next_timer    = nil
      @register_msg  = Yajl::Encoder.encode({:host => @host, :port => @port, :uri => @domain, :tags => {:component => "HttpBackend-#{name}"} })
    end

    def start
      @keep_checking = true
      check
      NATS.subscribe('router.start') do
        if @is_backend_alive
          NATS.publish('router.register', @register_msg)
        end
      end
    end

    def stop
      logger.debug("Stopping agent ...")
      @keep_checking = false
      if @next_timer
        EM.cancel_timer(@next_timer)
      end
      if @stop_on_exit && @stop_command
        stdout, stderr, status = Open3.capture3(@stop_command)
        logger.warn("stop result", {
          :stdout => stdout, :stderr => stderr, :status => status
        })
        if process_exists?
          logger.warn("Backend is still alive.")
        else
          @is_backend_alive = false
        end
      end
      # whether the backend is alive or not, we should unregister from router to recover routing table.
      NATS.publish('router.unregister', @register_msg)
    end

    def is_backend_alive?
      @is_backend_alive
    end

    protected
    def retry_check_after(interval)
      return false unless @keep_checking
      @next_timer = EM.add_timer(@monitor_interval) do
          @checking = false
          check
      end
    end

    def check
      return unless @keep_checking
      return if @checking
      @last_check = Time.now
      @checking = true
      unless process_exists?
        if @is_backend_alive # status changed
          NATS.publish('router.unregister', @register_msg)
        end
        @is_backend_alive = false
        if @auto_start && @start_command
          logger.warn("Backend `#{name}` does not exist, try to start by `#{@start_command}`")
          stdout, stderr, status = Open3.capture3(@start_command)
          logger.warn("start result", {
            :stdout => stdout, :stderr => stderr, :status => status
          })
          logger.debug("waiting #{@listen_delay} seconds for #{@name} listening.")
          return retry_check_after(@listen_delay)
        else
          logger.warn("Backend '#{name}' does not exist (auto_start = #{@auto_start})")
        end
      else
        unless @is_backend_alive # status changed
          NATS.publish('router.unregister', @register_msg)
        end
        @is_backend_alive = true
      end

      logger.debug("wait for #{@monitor_interval} seconds ... ")
      return retry_check_after(@monitor_interval)
    end

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