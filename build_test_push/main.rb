#! /usr/bin/env ruby

USERNAME = ENV['INPUT_USERNAME']
PASSWORD = ENV['INPUT_PASSWORD']
REGISTRY = ENV['INPUT_REGISTRY']
NAME = ENV['INPUT_NAME']
DEBUG_MODE = ENV['INPUT_DEBUG_MODE'] == "true"
TESTS = (ENV['INPUT_TESTS'] || []).split(",")
TEST_ENV_FILE = ENV['TEST_ENV_FILE']
GITHUB_REF = ENV['GITHUB_REF']

BASENAME = NAME.split("/")[-1]

def run
  check_inputs
  login unless DEBUG_MODE
  build
  test
  push unless DEBUG_MODE
end

def check_inputs
  %w(NAME GITHUB_REF).each do |name|
    var = Kernel.const_get(name)
    if var.nil? || var.strip == ""
      raise "Variable #{name} is not properly set."
    end
  end
  puts "Detected branch: #{sanitized_branch}"
end

def login
  sh "echo #{PASSWORD} | docker login -u #{USERNAME} --password-stdin #{REGISTRY}"
end

def build
  sh "docker build . -t #{BASENAME}"
end

def test
  env_file_opt = ""
  if TEST_ENV_FILE != nil
    env_file_opt= "--env-file=#{TEST_ENV_FILE}"
  end
  TESTS.each do |test|
    puts "Running test: #{test}"
    sh "docker run #{env_file_opt} #{BASENAME} #{test}"
  end
end

def push
  branch = sanitized_branch
  if branch.nil?
    puts "Only pushing images for branches (ref=#{GITHUB_REF})."
    return
  end
  tag = branch
  full_remote_image = "#{REGISTRY.gsub("https://", "")}/#{NAME}:#{tag}"
  sh "docker tag #{BASENAME}:latest #{full_remote_image}"
  sh "docker push #{full_remote_image}"
end

# helper methods

def sanitized_branch
  if GITHUB_REF.include?("refs/heads")
    return GITHUB_REF.gsub("refs/heads/", "").gsub("/", "-")
  else
    return nil
  end
end

def sh(cmd)
  puts "Running: #{cmd}"
  ret = system(cmd)
  raise "Command did not finish successfully" if ret != true
end

run
