require File.join(File.dirname(__FILE__), '../spec_helper')
require 'fileutils'
require 'nats/client'
require 'vcap/common'
require 'vcap/spec/forked_component'
require 'http_backend/agent'

describe "HttpBackend::Agent" do
  TEST_DIR = "/tmp/http_backend_agent"
  MOCK_SERVER = File.expand_path('../../fixtures/start_server.rb', __FILE__)

  before :each do
    FileUtils.mkdir(TEST_DIR)
    File.directory?(TEST_DIR).should be_true

    @nats_port     = VCAP.grab_ephemeral_port
    @nats_pid_file = File.join(TEST_DIR, "nats-#{@nats_port}.pid")
    @nats_server   = VCAP::Spec::ForkedComponent::NatsServer.new(@nats_pid_file, @nats_port, TEST_DIR)

    @nats_server.start
    wait_for { @nats_server.ready? }.should be_true
  end

  after :each do
    FileUtils.rm_rf(TEST_DIR)
    File.directory?(TEST_DIR).should be_false

    # @nats_server.stop
    # @nats_server.running?.should be_false
  end

  context "while monitoring" do
    describe "auto_start backend" do
      before :all do
        port = VCAP.grab_ephemeral_port
        pid_filename = File.join(TEST_DIR, "mock-server-#{port}.pid")
        @agent = VCAP::HttpBackend::Agent.new({
          "name"          => "mock-server",
          "domain"        => "foo.vcap.me",
          "host"          => "127.0.0.1",
          "port"          => 8080,
          "pid_filename"  => pid_filename,
          "start"         => "#{MOCK_SERVER} -p #{port} -P #{pid_filename}",
          "stop"          => "kill -9 $(cat #{pid_filename})",
          "auto_start"    => true,
          "stop_on_exit"  => true,
          "monitor_interval" => 3,
          "listen_delay"     => 1
          })
      end

      after :all do
      end

      it "should start/stop server" do
        EM.run do
          @agent.start
          EM.add_timer(9) do
            @agent.is_backend_alive?.should be_true
            @agent.stop
            @agent.is_backend_alive?.should be_false
            EM.stop
          end
        end
      end
    end
  end
end
