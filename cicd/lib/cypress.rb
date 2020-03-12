class CypressModule

  def prepare
    set :cypress_record_key, ENV['INPUT_CYPRESS_RECORD_KEY']
    set :cypress_record_enabled, ENV['INPUT_CYPRESS_RECORD_ENABLED'] == 'true'
  end

  def run
    # setup network
    sh "docker network create cicd"

    # prepare test database
    puts "Starting postgres..."
    sh "docker run --name=cicd-postgres --network=cicd --rm -e POSTGRES_PASSWORD=postgres -d postgres:9.6"
    puts "Postgres started"

    puts "Starting redis..."
    sh "docker run --name=cicd-redis --network=cicd --rm -d redis"
    puts "Redis started"

    puts "Preparing test database..."
    run_in_image "rake db:create"
    run_in_image "rake db:reset"
    puts "Test database prepared."

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
  end

  private

  # helpers

  def run_in_image(cmd, flags="")
    env_file_opt = ""
    if fetch(:test_env_file) != nil
      env_file_opt= "--env-file=#{fetch(:test_env_file)}"
    else
      raise "Test environment variable must be specified"
    end
    sh "docker run --network=cicd --rm #{flags} #{env_file_opt} #{fetch(:image_name)} #{cmd}"
  end

  def cypress_config
    cc = fetch(:cicd_config)
    return cc[:defaults][:cypress] || {}
  end

  def specs_to_run
    cypress_config[:specs] || []
  end

end
