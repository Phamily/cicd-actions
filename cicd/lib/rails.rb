class RailsModule

  def prepare

  end

  def run
    start_dependencies(seed: true)

    run_in_image "foreman start", "--name cicd-app -d"
  end

end