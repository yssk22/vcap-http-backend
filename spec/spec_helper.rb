$:.unshift File.join(File.dirname(__FILE__), '..')
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

home = File.join(File.dirname(__FILE__), '/..')
ENV['BUNDLE_GEMFILE'] = "#{home}/Gemfile"

require 'rubygems'
require 'rspec'
require 'bundler/setup'
require 'steno'

steno_config = Steno::Config.to_config_hash({})
steno_config[:context] = Steno::Context::ThreadLocal.new
Steno.init(Steno::Config.new(steno_config))

def wait_for(timeout=10, &predicate)
  start = Time.now()
  cond_met = predicate.call()
  while !cond_met && ((Time.new() - start) < timeout)
    cond_met = predicate.call()
    sleep(0.2)
  end
  cond_met
end
