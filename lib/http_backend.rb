require "steno"
require "nats/client"
require "vcap/component"
require "http_backend/config"
require "http_backend/agent"

module VCAP::HttpBackend
  class HttpBackend

    AGENT_GLOBAL_ATTRIBUTES = [:monitor_interval, :auto_start, :stop_on_exit, :listen_delay]

    def initialize(argv)
      @argv = argv
      @config_file = File.expand_path("../../config/http_backend.yml",
        __FILE__)
      parse_options!
      parse_config

      create_pidfile
      setup_logging
      @local_ip = VCAP.local_ip(@config[:local_route])
    end

    def start
      logger.info("starting...")
      EM.epoll
      NATS.start(:uri => @config[:nats_uri]) do
        register_as_vcap_component
        backend_configs = @config[:backend_servers] || []
        @backends = backend_configs.map do |config|
          AGENT_GLOBAL_ATTRIBUTES.each do |attr|
            config[attr.to_s] = @config[attr] if config[attr].nil?
          end
          config["host"] ||= @local_ip
          agent = Agent.new(config)
          agent.start
          agent
        end
        logger.debug("#{@backends.length} backend servers configured to register")
      end
    end

    def stop
      logger.info("shutting down...")
      @backends.each do |agent|
        agent.stop
      end
      NATS.stop { EM.stop }
      logger.info("bye.")
    end

    def register_as_vcap_component
      puts @config.inspect
      status_config = @config['status'] || {}
      VCAP::Component.register(:type => 'HttpBackend',
                               :host => @local_ip,
                               :index => @config[:index] || 0,
                               :config => @config,
                               :nats => @publisher,
                               :port => status_config[:port],
                               :user => status_config[:user],
                               :password => status_config[:password])
    end

    def options_parser
      @parser ||= OptionParser.new do |opts|
        opts.on("-c", "--config [ARG]", "Configuration File") do |opt|
          @config_file = opt
        end
      end
    end

    def parse_options!
      options_parser.parse! @argv
    rescue
      $stderr.puts options_parser
      exit 1
    end

    def parse_config
      @config = VCAP::HttpBackend::Config.from_file(@config_file)
    rescue Membrane::SchemaValidationError => ve
      $stderr.puts "ERROR: There was a problem validating the supplied config: #{ve}"
      exit 1
    rescue => e
      $stderr.puts "ERROR: Failed loading config from file '#{@config_file}': #{e}"
      exit 1
    end

    def create_pidfile
      begin
        pid_file = VCAP::PidFile.new(@config[:pid_filename])
        pid_file.unlink_at_exit
      rescue => e
        $stderr.puts "ERROR: Can't create pid file #{@config[:pid_filename]}"
        exit 1
      end
    end

    def setup_logging
      steno_config = Steno::Config.to_config_hash(@config[:logging])
      steno_config[:context] = Steno::Context::ThreadLocal.new
      Steno.init(Steno::Config.new(steno_config))
    end

    def logger
      @loger ||= Steno.logger('hb')
    end
  end
end
