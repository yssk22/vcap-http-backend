require 'vcap/common'
require 'vcap/config'

module VCAP::HttpBackend
  class Config < VCAP::Config
    define_schema do
      {
        optional(:local_route) => String,

        :logging => {
          :level            => String,
          optional(:file)   => String,
          optional(:syslog) => String
        },

        :nats_uri                 => String,
        :pid_filename             => String,

        # Global Configuration
        optional(:monitor_interval) => Integer,
        optional(:auto_start)       => bool,
        optional(:stop_on_exit)     => bool,
        optional(:listen_delay)     => Integer,

        # Each backend configuration
        optional(:backend_servers) => [{
          "name"   => String,
          "domain" => String,
          "port"   => Integer,
          optional(:host)             => String,
          optional(:pid_filename)     => String,
          optional(:start)            => String,
          optional(:stop)             => String,
          optional(:monitor_interval) => Integer,
          optional(:listen_delay)     => Integer,
          optional(:auto_start)       => bool,
          optional(:stop_on_exit)     => bool
        }],

        optional("status") => {
          optional(:port) => Integer,
          optional(:user) => String,
          optional(:password) => String
        }
      }
    end
  end
end