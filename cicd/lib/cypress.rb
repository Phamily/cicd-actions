require 'securerandom'

class CypressModule

  def prepare
    set :cypress_record_key, ENV['INPUT_CYPRESS_RECORD_KEY']
    set :cypress_record_enabled, ENV['INPUT_CYPRESS_RECORD_ENABLED'] == 'true'
    set :cypress_use_deploy_url, ENV['INPUT_CYPRESS_USE_DEPLOY_URL'] == 'true'
    set :cypress_base_url, ENV['INPUT_CYPRESS_BASE_URL']
    set :cypress_parallel_count, (ENV['INPUT_CYPRESS_PARALLEL_COUNT'] || 1).to_i
  end

  def run
    use_deploy = fetch(:cypress_use_deploy_url)
    base_url = fetch(:cypress_base_url)
    use_external_server = use_deploy || !base_url.nil?
    flag_base_url = ""
    instance_count = fetch(:cypress_parallel_count)
    
    # check if can run
    if !can_run?(cypress_config["run_on"]) || cypress_config["skip"] == true
      puts "Cypress is not enabled for this event/branch."
      return
    end

    if use_external_server
      if use_deploy
        # determine environment to run against
        denv = branch_environments.first
        if denv.nil?
          puts "No deploy environment for Cypress to use."
        end
        base_url = denv["kube"]["env"]["PHAMILY_HOST_URL"]
      end
      base_url = "http://" + base_url if !base_url.start_with?("http")
      flag_base_url = "-e CYPRESS_BASE_URL=#{base_url}"
      puts "Using base url: #{base_url}"
    else
      # start dependencies
      start_dependencies(seed: true) unless fetch(:keep_dependencies)

      # start docker and bind to port 3000
      puts "Starting server in background."
      svr_cmd = cypress_config["server_command"] || "bundle exec rails s -p 3000 -b 0.0.0.0"
      run_in_image svr_cmd, "--name=cicd-app -d"
      flag_base_url = "--network=cicd"
    end

    # build cypress container
    sh "docker build . -f /cicd/Dockerfile.cypress -t cypress-runner"

    # run
    instances = []
    flag_record = fetch(:cypress_record_enabled) ? "--record" : ""
    flag_parallel = ""
    if instance_count > 1
      flag_parallel = "--parallel --ci-build-id #{Time.now.to_i}"
    end
    specs = specs_to_run
    flag_specs = specs.empty? ? "" : " --spec \"#{specs.join(",")}\""
    instance_count.times do
      name = "cypress-#{SecureRandom.hex(8)}"
      sh "docker run --name=#{name} -d --ipc=host #{flag_base_url} -e CYPRESS_RECORD_KEY=#{fetch(:cypress_record_key)} cypress-runner run --headless --browser chrome #{flag_record} #{flag_parallel} #{flag_specs}"
      instances << name
    end

    # wait for cypress to finish
    puts "Waiting for cypress to finish. Check cypress.io for run details."
    sh "docker wait #{instances.join(" ")}"

    succeeded = true
    instances.each do |inst|
      sh "docker logs #{inst}"
      succeeded = false if `docker inspect #{inst} --format='{{.State.ExitCode}}'`.to_i != 0
    end

    sh "docker rm $(docker ps -a -f status=exited | grep cypress | awk '{print $1}')"

    # stop dependencies
    if !use_external_server
      sh "docker rm -f cicd-app"
      stop_dependencies
    end
    if !succeeded
      raise "Cypress tests did not succeed."
    end
  end

  private

  # helpers

  def cypress_config
    bc = branch_settings
    return bc["cypress"] || {}
  end

  def specs_to_run
    cypress_config["specs"] || []
  end

end
