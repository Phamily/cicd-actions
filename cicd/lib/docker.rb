class DockerModule

  def prepare
    set :registry_url, ENV['INPUT_REGISTRY_URL']
    set :registry_username, ENV['INPUT_REGISTRY_USERNAME']
    set :image_tar, ENV['INPUT_IMAGE_TAR']
    set :image_namespace, ENV['INPUT_IMAGE_NAMESPACE']
    set :image_basename, fetch(:image_name).split("/")[-1]
    set :build_artifact, ENV['INPUT_BUILD_ARTIFACT'] == "true"
    set :build_from_cache, ENV['INPUT_BUILD_FROM_CACHE'] == "true"
    set :copy_paths, ENV['INPUT_COPY_PATHS']
  end

  def get_ecr_token
    return if present?(fetch(:registry_password))
    resp = `aws ecr get-authorization-token`
    json = JSON.parse(resp)
    auth_data = json["authorizationData"].first
    token = Base64.decode64(auth_data["authorizationToken"])
    ts = token.split(":")
    ep = auth_data["proxyEndpoint"]
    set :registry_url, ep
    set :registry_username, ts[0]
    set :registry_password, ts[1]
  end

  def login
    get_ecr_token
    sh "echo #{fetch(:registry_password)} | docker login -u #{fetch(:registry_username)} --password-stdin #{fetch(:registry_url)}", text: "Login command"
  end

  def build
    flag_cf = ""
    if fetch(:build_from_cache)
      puts "Attempting to build from cache"
      # login to registry
      login
      cache_image = nil
      # pull image
      [sanitized_branch, "develop", "master"].each do |br|
        begin 
          cache_image = pull_image(br)
        rescue => ex
          puts "Could not pull #{br} remote image for cache."
        end
        if cache_image
          flag_cf = "--cache-from #{cache_image}"
          break
        end
      end
    end
    sh "docker build #{flag_cf} -t #{fetch(:image_name)} ."
    if fetch(:build_artifact)
      sh "docker image save --output image.tar #{fetch(:image_name)}"
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
      puts "Only pushing images for branches (ref=#{fetch(:github_ref)})."
      return
    end
    tag = branch
    frin = full_remote_image_name(tag)
    sh "docker tag #{fetch(:image_name)}:latest #{frin}"
    sh "docker push #{frin}"
  end

  def copy_paths
    paths = fetch(:copy_paths)
    img = fetch(:image_name)
    cid = `docker create #{img}`.strip
    stat = File.stat("/github/workspace")
    paths.split(",").each do |path|
      puts "Copying path #{path}"
      pdir = File.dirname(path)
      sh "mkdir -p #{pdir}"
      sh "docker cp #{cid}:/app/#{path}/. #{path}"
      #sh "docker cp -v /github/workspace:/ws #{img} cp -r #{path} #{outdir}/"
      sh "chown -R #{stat.uid}:#{stat.gid} #{path}"
      sh "ls -al /github/workspace"
      sh "ls -al #{pdir}"
      sh "ls -al #{path}"
    end
    sh "docker rm #{cid}"
  end

  private

  def full_remote_image_name(tag)
    full_remote_image = "#{fetch(:registry_url).gsub("https://", "")}/#{fetch(:image_namespace)}/#{fetch(:image_name)}:#{tag}"
  end

  def pull_image(tag)
    frin = full_remote_image_name(tag)
    puts "Pulling image"
    sh "docker pull #{frin}"
    return frin
  end

end
