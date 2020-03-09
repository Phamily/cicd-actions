#! /usr/bin/env ruby

require_relative 'lib/docker'
require_relative 'lib/cypress'

MODULES = {
  docker: DockerModule.new,
  cypress: CypressModule.new,
}
OPTIONS = {}

def run
  prepare
  fetch(:tasks).each do |task|
    puts "===== RUNNING TASK (#{task}) ====="
    tps = task.split(":")
    MODULES[tps[0].to_sym].send(tps[1])
  end
end

def prepare
  set :tasks, ENV['INPUT_TASKS'].split(",")
  set :image_name, ENV['INPUT_IMAGE_NAME']
  set :test_env_file, ENV['INPUT_TEST_ENV_FILE']
  set :github_ref, ENV['GITHUB_REF']
  MODULES.each do |key, mod|
    mod.prepare
  end
  puts "Detected branch: #{sanitized_branch}"
end

# helper methods

def sanitized_branch
  ref = fetch(:github_ref)
  if ref.include?("refs/heads")
    return ref.gsub("refs/heads/", "").gsub("/", "-")
  else
    return nil
  end
end

def sh(cmd)
  puts "Running: #{cmd}"
  ret = system(cmd)
  raise "Command did not finish successfully" if ret != true
end

def set(name, val)
  OPTIONS[name.to_sym] = val
end

def fetch(name)
  OPTIONS[name]
end

def register_module(name, mod)
  MODULES[name] = mod
end


run
