#!/usr/bin/env ruby
require 'optparse'
require 'fileutils'
require 'socket'

port = nil
pidfile = nil
OptionParser.new { |opts|
  opts.on('-p', '--port PORT', Integer, "Port to bind to") do |p|
    port = p
  end
  opts.on('-P', '--pid FILE', String, "Pidfile path to write") do |p|
    pidfile = p
  end
}.parse(ARGV)

unless port
  $stderr.puts "-p PID must be specified."
  exit 1
end
unless pidfile
  $stderr.puts "-P FILE must be specified."
  exit 1
end

Process.daemon()
open(pidfile, "w") do |f|
  f.write(Process.pid)
end
server = TCPServer.new('127.0.0.1', port)
while true do
  client = server.accept()
  client.close()
end

