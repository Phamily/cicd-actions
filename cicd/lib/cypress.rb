class CypressModule

  def prepare
    set :cypress_record_key, ENV['INPUT_CYPRESS_RECORD_KEY']
    set :cypress_record_enabled, ENV['INPUT_CYPRESS_RECORD_ENABLED'] == 'true'
  end

  def run
    # check if can run
    if !can_run?(cypress_config["run_on"]) || cypress_config["skip"] == true
      puts "Cypress is not enabled for this event/branch."
      return
    end
    start_dependencies

    # start docker and bind to port 3000
    puts "Starting server in background."
    run_in_image "rails s -p 3000 -b 0.0.0.0", "--name=cicd-app -d"

    # build cypress container
    sh "docker build . -f /cicd/Dockerfile.cypress -t cypress-runner"

    # run
    flag_record = fetch(:cypress_record_enabled) ? "--record" : ""
    specs = specs_to_run
    flag_specs = specs.empty? ? "" : " --spec \"#{specs.join(",")}\""
    sh "docker run --network=cicd --rm -e CYPRESS_RECORD_KEY=#{fetch(:cypress_record_key)} cypress-runner run #{flag_record}#{flag_specs}"
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
