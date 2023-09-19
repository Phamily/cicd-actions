class PlaywrightModule

  def prepare
    set :playwright_command, ENV['INPUT_PLAYWRIGHT_COMMAND']
    set :playwright_base_url, ENV['INPUT_PLAYWRIGHT_BASE_URL']
  end

  def run
    # build playwright image with specs
    cmd = "docker build . -f /cicd/Dockerfile.playwright -t playwright-runner"
    sh cmd

    # run playwright image
    pcmd = fetch(:playwright_command)
    purl = fetch(:playwright_base_url)
    base_url = purl || "http://cicd-app:3000"
    cmd = "docker run --network=cicd --rm --ipc=host --env PLAYWRIGHT_TEST_BASE_URL=#{base_url} --env CI=true playwright-runner #{pcmd}"
    sh cmd
  end

end