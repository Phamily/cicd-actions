class RspecModule

  def prepare

  end

  def run
    if rspec_config["skip"] == true
      puts "Skipping rspec run for this branch."
      return
    end

    start_dependencies

    specs = specs_to_run
    files_args = ""
    if specs.is_a?(Array)
      files_args = specs_to_run.join(" ")
    elsif specs == "all"
      files_args = ""
    end
    run_in_image "bundle exec rspec #{files_args}"
    stop_dependencies
  end

  def rspec_config
    bc = branch_settings
    return bc["rspec"] || {}
  end

  def specs_to_run
    specs = rspec_config["specs"] || 'all'
  end

end
