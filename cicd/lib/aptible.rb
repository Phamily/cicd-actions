class AptibleModule

  def prepare
    set :aptible_environment, ENV['INPUT_APTIBLE_ENVIRONMENT']
    set :aptible_app, ENV['INPUT_APTIBLE_APP']
    set :aptible_email, ENV['INPUT_APTIBLE_EMAIL']
    set :aptible_password, ENV['INPUT_APTIBLE_PASSWORD']
  end

  def login
    apt_email = fetch(:aptible_email)
    apt_pw = fetch(:aptible_password)
    sh "aptible login --email #{apt_email} --password #{apt_pw}"
  end

  def deploy
    login
    apt_env = fetch(:aptible_environment)
    apt_app = fetch(:aptible_app)
    iuri = full_remote_image_name
    pru = fetch(:registry_username)
    prp = fetch(:registry_password)

    sh "aptible deploy --environment #{apt_env} --app #{apt_app}--docker-image #{iuri} --private-registry-username #{pru} --private-registry-password #{prp}"
  end

end