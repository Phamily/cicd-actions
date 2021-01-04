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
      [image_tag, tmp_image_tag, "develop", "master"].each do |br|
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
    flin = full_local_image_name
    sh "docker build #{flag_cf} -t #{flin} ."
    if fetch(:build_artifact)
      sh "docker image save --output image.tar #{flin}"
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
    login
    rtag = image_tag
    if rtag.nil?
      puts "Only pushing images for branches (ref=#{fetch(:github_ref)})."
      return
    end
    frin = full_remote_image_name
    flin = full_local_image_name
    sh "docker tag #{flin} #{frin}"
    sh "docker push #{frin}"
  end

  def pull
    login
    image = pull_image(tmp_image_tag, tag_locally: true)
  end

  def retag
    login
    repo_name = "#{fetch(:image_namespace)}/#{fetch(:image_name)}"
    tmp_tag = tmp_image_tag

    # find image manifest
    manifest = `aws ecr batch-get-image --repository-name #{repo_name} --image-ids imageTag=#{tmp_tag} --query 'images[].imageManifest' --output text`
    raise "Image manifest not found" if manifest == "" || manifest.nil?
    puts "Found image manifest: #{manifest}"
    File.write("/tmp/img_manifest.json", manifest)

    # set new tag
    `aws ecr put-image --repository-name #{repo_name} --image-tag #{image_tag} --image-manifest file:///tmp/img_manifest.json`
    puts "Image retagged to #{image_tag}."
  end

  def prune_images
    puts "Pruning unused images."
    sh "docker image prune -f"
  end

  def copy_paths
    paths = fetch(:copy_paths)
    flin = full_local_image_name
    cid = `docker create #{flin}`.strip
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

  def pull_image(tag, opts={})
    frin = full_remote_image_name(tag: tag)
    flin = full_local_image_name(tag: tag)
    puts "Pulling image"
    sh "docker pull #{frin}"
    if opts[:tag_locally]
      puts "Tagging image locally"
      sh "docker tag #{frin} #{flin}"
    end
    return frin
  end

end
