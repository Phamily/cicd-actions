#! /usr/bin/env ruby

require_relative 'lib/docker'
require_relative 'lib/cypress'
require_relative 'lib/kube'
require_relative 'lib/rspec'
require_relative 'lib/lambda'
require_relative 'lib/aptible'
require 'erb'
require 'yaml'
require 'base64'
require 'json'

MODULES = {
  docker: DockerModule.new,
  cypress: CypressModule.new,
  kube: KubeModule.new,
  rspec: RspecModule.new,
  lambda: LambdaModule.new,
  aptible: AptibleModule.new
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
  set :image_tag_style, ENV['INPUT_IMAGE_TAG_STYLE'] || 'branch'
  set :use_temporary_remote_image, ENV['INPUT_USE_TEMPORARY_REMOTE_IMAGE'] != "false"
  set :image_env_file, ENV['INPUT_IMAGE_ENV_FILE']
  set :aws_access_key, ENV['INPUT_AWS_ACCESS_KEY']
  set :aws_secret_access_key, ENV['INPUT_AWS_SECRET_ACCESS_KEY']
  set :aws_region, ENV['INPUT_AWS_REGION']
  set :keep_dependencies, ENV['INPUT_KEEP_DEPENDENCIES'] == "true"

  # github env vars
  set :github_ref, ENV['GITHUB_REF']
  set :github_sha, ENV['GITHUB_SHA']
  set :github_event_name, ENV['GITHUB_EVENT_NAME']

  # cicd config
  if File.exists?(".github/cicd.yml")
    set :cicd_config, YAML.load( parse_erb(".github/cicd.yml") )
  else
    raise "Please add .github/cicd.yml"
  end

  # set aws config
  configure_aws

  # modules
  MODULES.each do |key, mod|
    mod.prepare
  end
  puts "Detected Github event: #{fetch(:github_event_name)}"
  puts "Detected branch: #{branch}"
  puts "Current working directory: #{Dir.pwd}"
end

def start_dependencies(opts={})
  stop_dependencies(ignore_error: true)

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
  run_in_image "bundle exec rake db:create"
  run_in_image "bundle exec rake db:schema:load"
  if opts[:seed]
    run_in_image "bundle exec rake db:seed"
  end
  puts "Test database prepared."
end

def stop_dependencies(ignore_error: false)
  sh "docker rm -f $(docker ps -aq --filter=\"network=cicd\")", ignore_error: ignore_error
  sh "docker network rm cicd", ignore_error: ignore_error
end

# helper methods

def branch
  ref = fetch(:github_ref)
  if ref.include?("refs/heads")
    return ref.gsub("refs/heads/", "")
  elsif ref.include?("refs/tags")
    return ref.gsub("refs/tags/", "")
  else
    return nil
  end
end

def sanitized_branch
  b = branch
  return nil if b.nil?
  return b.gsub("/", "-")
end

def image_tag
  ret = sanitized_branch
  if fetch(:image_tag_style) == 'sha'
    ret = fetch(:github_sha)[0..6]
  end
  return ret
end

def tmp_image_tag
  ret = image_tag
  return nil if ret.nil?
  ret = "tmp-#{ret}"
  return ret
end

def branch_settings
  cc = fetch(:cicd_config)
  bc = (cc["branch_settings"] || {})[branch] || {}
  return merge_with_options(cc["defaults"], bc)
end

def branch_environments
  cc = fetch(:cicd_config)
  return cc["environments"].select{|e| e['branch'] == branch}
end

def can_run?(opts)
  return true if opts.nil?
  ref = fetch(:github_ref)
  ev = fetch(:github_event_name)
  opts.each do |ev, eopts|
    case ev
    when 'push'
      next if ev != 'push'
      if eopts["branches"].is_a?(Array)
        return eopts["branches"].include?(branch)
      else
        return true
      end
    when 'pull_request'
      return ev == 'pull_request'
    end
  end
  return false
end

def full_remote_image_name(tag: nil)
  if tag.nil?
    tag = fetch(:use_temporary_remote_image) ? tmp_image_tag : image_tag
  end
  full_remote_image = "#{fetch(:registry_url).gsub("https://", "")}/#{fetch(:image_namespace)}/#{fetch(:image_name)}:#{tag}"
end

def full_local_image_name(tag: nil)
  if tag.nil?
    tag = fetch(:use_temporary_remote_image) ? tmp_image_tag : image_tag
  end
  return "#{fetch(:image_name)}:#{tag}"
end

def run_in_image(cmd, flags="")
  env_file_opt = ""
  flin = full_local_image_name
  if fetch(:image_env_file) != nil
    env_file_opt= "--env-file=#{fetch(:image_env_file)}"
  else
    raise "Image environment variable file must be specified"
  end
  sh "docker run --network=cicd --rm #{flags} #{env_file_opt} #{flin} #{cmd}"
end

def parse_erb(file_path)
  erb = ERB.new(File.read(file_path))
  return erb.result(binding)
end

def sh(cmd, opts={})
  txt = opts[:text] || cmd
  puts "Running: #{txt}"
  ret = system(cmd)
  raise "Command did not finish successfully" if ret != true && opts[:ignore_error] != true
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
    memo.deep_merge(hash.transform_keys(&:to_s))
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

  def with_symbolized_keys
    self.transform_keys(&:to_sym)
  end
end

run
