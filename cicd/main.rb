#! /usr/bin/env ruby

require_relative 'lib/docker'
require_relative 'lib/cypress'
require_relative 'lib/kube'
require_relative 'lib/rspec'
require 'erb'
require 'yaml'
require 'base64'
require 'json'

MODULES = {
  docker: DockerModule.new,
  cypress: CypressModule.new,
  kube: KubeModule.new,
  rspec: RspecModule.new,
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
  set :image_namespace, ENV['INPUT_IMAGE_NAMESPACE']
  set :image_env_file, ENV['INPUT_IMAGE_ENV_FILE']
  set :aws_access_key, ENV['INPUT_AWS_ACCESS_KEY']
  set :aws_secret_access_key, ENV['INPUT_AWS_SECRET_ACCESS_KEY']
  set :aws_region, ENV['INPUT_AWS_REGION']

  # github env vars
  set :github_ref, ENV['GITHUB_REF']

  # cicd config
  if File.exists?(".github/cicd.yml")
    set :cicd_config, YAML.load_file(".github/cicd.yml")
  else
    raise "Please add .github/cicd.yml"
  end

  # set aws config
  configure_aws

  # modules
  MODULES.each do |key, mod|
    mod.prepare
  end
  puts "Detected branch: #{branch}"
end

def start_dependencies
  # setup network
  sh "docker network create cicd"

  # prepare test database
  puts "Starting postgres..."
  sh "docker run --name=cicd-postgres --network=cicd --rm -e POSTGRES_PASSWORD=postgres -d postgres:9.6"
  puts "Postgres started"

  puts "Starting redis..."
  sh "docker run --name=cicd-redis --network=cicd --rm -d redis"
  puts "Redis started"

  puts "Preparing database..."
  run_in_image "rake db:create"
  run_in_image "rake db:reset"
  puts "Test database prepared."
end

def stop_dependencies
  sh "docker rm -f cicd-postgres cicd-redis"
  sh "docker network rm cicd"
end

# helper methods

def branch
  ref = fetch(:github_ref)
  if ref.include?("refs/heads")
    return ref.gsub("refs/heads/", "")
  else
    return nil
  end
end

def sanitized_branch
  b = branch
  return nil if b.nil?
  return b.gsub("/", "-")
end

def run_in_image(cmd, flags="")
  env_file_opt = ""
  if fetch(:image_env_file) != nil
    env_file_opt= "--env-file=#{fetch(:image_env_file)}"
  else
    raise "Image environment variable file must be specified"
  end
  sh "docker run --network=cicd --rm #{flags} #{env_file_opt} #{fetch(:image_name)} #{cmd}"
end

def sh(cmd, opts={})
  txt = opts[:text] || cmd
  puts "Running: #{txt}"
  ret = system(cmd)
  raise "Command did not finish successfully" if ret != true
end

def set(name, val)
  OPTIONS[name.to_sym] = val
end

def fetch(name, opts={})
  ret = OPTIONS[name]
  if opts[:required] == true && ret.nil?
    raise "Config variable #{name} was requested but is nil."
  end
  return ret
end

def register_module(name, mod)
  MODULES[name] = mod
end

def write_template_file(inpath, outpath, opts={})
  context = opts[:context]
  b = KubeFileBinding.new(context)
  File.write(outpath, b.erb_result(inpath))
end

def present?(var)
  var != "" && !var.nil?
end

def configure_aws
  aws_ak = fetch(:aws_access_key)
  aws_sak = fetch(:aws_secret_access_key)
  aws_reg = fetch(:aws_region)
  return if !present?(aws_ak)
  puts "Configuring AWS Credentials."
  # write aws config
  sh "mkdir -p #{ENV['HOME']}/.aws"
  File.write "#{ENV['HOME']}/.aws/credentials", "[default]\naws_access_key_id = #{aws_ak}\naws_secret_access_key = #{aws_sak}\n"
  File.write "#{ENV['HOME']}/.aws/config", "[default]\nregion = #{aws_reg}\noutput = json\n"
end

def merge_with_options(*hashes)
  hashes.reduce(OPTIONS) {|memo, hash|
    memo.deep_merge(hash.transform_keys(&:to_sym))
  }
end

class KubeFileBinding

  def initialize(context)
    @context = context
  end

  def context
    @context
  end

  def var(name)
    context[name.to_sym] || context[name.to_s]
  end

  def erb_result(inpath)
    erb = ERB.new(File.read(inpath))
    return erb.result(binding)
  end

end

class ::Hash
  def deep_merge(second)
    merger = proc { |_, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
    merge(second.to_h, &merger)
  end
end

run
