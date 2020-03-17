class RspecModule

  def prepare

  end

  def run
    start_dependencies

    files_args = specs_to_run.join(" ")
    run_in_image "rspec #{files_args}"
    stop_dependencies
  end

  def rspec_config
    cc = fetch(:cicd_config)
    return cc["defaults"]["rspec"] || {}
  end

  def specs_to_run
    rspec_config["specs"] || []
  end

end
