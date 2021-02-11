class CypressModule

  def prepare
    set :cypress_record_key, ENV['INPUT_CYPRESS_RECORD_KEY']
    set :cypress_record_enabled, ENV['INPUT_CYPRESS_RECORD_ENABLED'] == 'true'
    set :cypress_use_deploy_url, ENV['INPUT_CYPRESS_USE_DEPLOY_URL'] == 'true'
  end

  def run
    use_deploy = fetch(:cypress_use_deploy_url)
    flag_deploy = ""
    
    # check if can run
    if !can_run?(cypress_config["run_on"]) || cypress_config["skip"] == true
      puts "Cypress is not enabled for this event/branch."
      return
    end

    if use_deploy
      # determine environment to run against
      denv = branch_environments.first
      if denv.nil?
        puts "No deploy environment for Cypress to use."
      end
      deploy_url = denv["kube"]["env"]["PHAMILY_HOST_URL"]
      deploy_url = "http://" + deploy_url if !deploy_url.start_with?("http")
      flag_deploy = "-e CYPRESS_BASE_URL=#{deploy_url}"
      puts "Using deploy url: #{deploy_url}"
    else
      # start dependencies
      start_dependencies(seed: true) unless fetch(:keep_dependencies)

      # start docker and bind to port 3000
      puts "Starting server in background."
      svr_cmd = cypress_config["server_command"] || "bundle exec rails s -p 3000 -b 0.0.0.0"
      run_in_image svr_cmd, "--name=cicd-app -d"
      flag_deploy = "--network=cicd"
    end

    # build cypress container
    sh "docker build . -f /cicd/Dockerfile.cypress -t cypress-runner"

    # run
    flag_record = fetch(:cypress_record_enabled) ? "--record" : ""
    specs = specs_to_run
    flag_specs = specs.empty? ? "" : " --spec \"#{specs.join(",")}\""
    sh "docker run --ipc=host --rm #{flag_deploy} -e CYPRESS_RECORD_KEY=#{fetch(:cypress_record_key)} cypress-runner run --headless --browser chrome #{flag_record}#{flag_specs}"
    sh "docker rm -f cicd-app"
    stop_dependencies
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
