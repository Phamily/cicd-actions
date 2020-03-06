class DockerModule

  def prepare
    set :registry_username, ENV['INPUT_REGISTRY_USERNAME']
    set :image_name, ENV['INPUT_IMAGE_NAME']
    set :image_namespace, ENV['INPUT_IMAGE_NAMESPACE']
    set :image_basename, fetch(:image_name).split("/")[-1]
    set :build_artifact, ENV['INPUT_BUILD_ARTIFACT'] == "true"
  end

  def login
    sh "echo #{fetch(:registry_password)} | docker login -u #{fetch(:registry_username)} --password-stdin #{fetch(:registry)}"
  end

  def build
    if fetch(:build_artifact)
      sh "docker build . -t #{fetch(:image_name)}"
      sh "docker image save --output image.tar #{fetch(:image_name)}"
    else
      sh "docker build . -t #{fetch(:image_name)}"
    end
  end

  def load_image
    sh "docker load --input #{fetch(:image_tar)}"
  end

  def test
    env_file_opt = ""
    if TEST_ENV_FILE != nil
      env_file_opt= "--env-file=#{TEST_ENV_FILE}"
    end
    TESTS.each do |test|
      puts "Running test: #{test}"
      sh "docker run #{env_file_opt} #{BASENAME} #{test}"
    end
  end

  def push
    branch = sanitized_branch
    if branch.nil?
      puts "Only pushing images for branches (ref=#{GITHUB_REF})."
      return
    end
    tag = branch
    full_remote_image = "#{REGISTRY.gsub("https://", "")}/#{NAME}:#{tag}"
    sh "docker tag #{BASENAME}:latest #{full_remote_image}"
    sh "docker push #{full_remote_image}"
  end


end
