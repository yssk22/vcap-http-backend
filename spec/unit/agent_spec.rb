require File.join(File.dirname(__FILE__), '../spec_helper')
require 'http_backend/agent'

describe "HttpBackend::Agent" do
  UNIT_TESTS_DIR = "/tmp/http_backend_agent"

  before :all do
  end

  before :each do
    FileUtils.mkdir(UNIT_TESTS_DIR)
    File.directory?(UNIT_TESTS_DIR).should be_true
  end

  after :each do
    FileUtils.rm_rf(UNIT_TESTS_DIR)
    File.directory?(UNIT_TESTS_DIR).should be_false
  end

  describe "attributes" do
    it 'should be configured from Hash' do
      agent = VCAP::HttpBackend::Agent.new({
        "name"          => "sample-agent",
        "domain"        => "foo.vcap.me",
        "host"          => "127.0.0.1",
        "port"          => 8080,
        "pid_filename"  => File.join(UNIT_TESTS_DIR, "sample-agent.pid"),
        "auto_start"    => false,
        "stop_on_exit"  => false,
        "start" => File.join(UNIT_TESTS_DIR, "start-sample-agent"),
        "stop"  => File.join(UNIT_TESTS_DIR, "stop-sample-agent")
        })
      agent.name.should          eq "sample-agent"
      agent.domain.should        eq "foo.vcap.me"
      agent.host.should          eq "127.0.0.1"
      agent.port.should          eq 8080
      agent.pid_filename.should  eq File.join(UNIT_TESTS_DIR, "sample-agent.pid")
      agent.auto_start.should    be_false
      agent.stop_on_exit.should  be_false
      agent.start_command.should eq File.join(UNIT_TESTS_DIR, "start-sample-agent")
      agent.stop_command.should  eq File.join(UNIT_TESTS_DIR, "stop-sample-agent")

      # not passed parameters
      agent.monitor_interval.should  eq 30
      agent.listen_delay.should      eq 30

    end
  end
end
