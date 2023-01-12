class KubeModule

  def prepare
    set :kube_cluster_name, ENV['INPUT_KUBE_CLUSTER_NAME']
    set :deploy_url_env_var, ENV['INPUT_DEPLOY_URL_ENV_VAR']
  end

  def config
    aws_reg = fetch(:aws_region)
    clust = fetch(:kube_cluster_name, required: true)
    # update kubeconfig
    sh "aws eks --region #{aws_reg} update-kubeconfig --name #{clust}"
    sh "kubectl get nodes"
  end

  def apply
    # iterate environments to apply
    puts "Applying to requested environments."
    cicd = fetch(:cicd_config)
    cicd["environments"].each do |e|
      if !branch.nil? && e["branch"] == branch
        build_vars(e)
        create_namespace(e)
        apply_environment(e)
        update_dns(e)
      end
    end
  end

  def output_deploy_url
    denv = branch_environments.first
    if denv.nil?
      puts "::set-output name=deploy_url::none"
    else
      deploy_url = denv["kube"]["env"]["PHAMILY_HOST_URL"] || denv["kube"]["env"][fetch(:deploy_url_env_var)]
      deploy_url = "http://" + deploy_url if !deploy_url.start_with?("http")
      puts "::set-output name=deploy_url::#{deploy_url}"
    end
  end

  private

  def build_vars(e)
    rurl = fetch(:registry_url, required: true)
    imnms = fetch(:image_namespace, required: true)
    im = fetch(:image_name, required: true)
    set :kube_namespace, e["kube"]["namespace"]
    set :app_image_url, "#{rurl}/#{imnms}/#{im}:#{sanitized_branch}"
  end

  def create_namespace(e)
    ns = e["kube"]["namespace"]
    sh "kubectl create namespace #{ns} --dry-run -o yaml | kubectl apply -f -"
  end

  def apply_environment(e)
    puts "Applying to the #{e["name"]} environment."
    # iterate needed manifests
    svc_comps = []
    init_comps = []
    depl_comps = []
    cicdc = fetch(:cicd_config)
    svcs = (e["kube"]["services"] ||= [])
    jobs = (e["kube"]["jobs"] ||= [])
    apps = (e["kube"]["apps"] ||= [])
    (svcs | jobs | apps).each do |comp|
      next if comp["skip"] == true
      name = comp["name"]
      cm = comp["manifest"] || comp["name"]
      manifest = "/kube/build/#{name}.yml"
      puts "Building manifest #{name}."
      ctx = merge_with_options(cicdc["defaults"], e["kube"], comp)
      write_template_file("/kube/#{cm}.yml.erb", manifest, context: ctx.with_symbolized_keys)
      puts File.read(manifest)
      comp["build_manifest"] = manifest
    end

    puts "Stopping required existing components"
    apps.select{|c| c['stop_on_deploy'] == true}.each do |c|
      kubecmd "delete deployment #{c["name"]} --ignore-not-found"
    end

    puts "Updating service components."
    svcs.each do |c|
      next if c["skip"] == true
      puts "Updating service: #{c["name"]}"
      kubecmd "apply -f #{c["build_manifest"]}"
      # wait for finished
      wait_for_resource("deployment", c["name"])
    end

    puts "Running pre-app job components."
    jobs.select{|j| j['run_stage'] != 'post_app'}.each do |c|
      run_resource('job', c)
    end

    puts "Updating deployment components."
    kubecmd "apply #{apps.select{|c| c["skip"] != true}.map{|c| "-f #{c["build_manifest"]}"}.join(" ")}"

    puts "Running post-app job components."
    jobs.select{|j| j['run_stage'] == 'post_app'}.each do |c|
      run_resource('job', c)
    end
  end

  def update_dns(e)
    return if e["kube"]["routing_mode"] != 'auto'
    # determine traefik load balancer IP
    lb_ip = get_traefik_load_balancer_ip
    var_name = (e["deploy"] || {})["url_env_var"]
    uri = URI.parse(e["kube"]["env"][var_name])
    host = uri.host
    MODULES[:aws].update_dns_record({host: host, type: "CNAME", value: lb_ip})
  end

  def run_resource(type, c)
    return if c["skip"] == true
    puts "Running #{type}: #{c["name"]}"
    if type == 'job'
      # delete previous job if present
      kubecmd "delete job #{c["name"]} --ignore-not-found"
    end
    # run 
    kubecmd "apply -f #{c["build_manifest"]}"
    if c["wait"] != false
      # wait for finished
      wait_for_resource(type, c["name"])
      # get logs
      kubecmd "logs #{type}/#{c["name"]}"
    end
  end

  def wait_for_resource(type, name, opts={})
    type = type.to_s
    timeout = opts[:timeout] || 600
    timeout_at = Time.now + timeout
    puts "Waiting for #{type} #{name}."
    loop do
      js = JSON.parse(`kubectl --namespace #{fetch(:kube_namespace)} get #{type}/#{name} -o json`)
      case type
      when "job"
        if js['status']['failed'].to_i > 0
          kubecmd "logs job/#{name}"
          raise "Job did not successfully finish."
        end
        if js['status']['succeeded'].to_i >= js['spec']['completions'].to_i
          puts "Job completed successfully."
          break
        end
      when "deployment"
        if js['status']['readyReplicas'].to_i >= js['status']['replicas'].to_i
          puts "Deployment is ready."
          break
        end
      end

      if Time.now > timeout_at
        kubecmd "logs #{type}/#{name}"
        raise "Timeout occurred waiting."
      else
        sleep 10
      end
    end
  end

  def get_traefik_load_balancer_ip
    svc = JSON.parse(`kubectl -n traefik get service traefik -o json`)
    svc["status"]["loadBalancer"]["ingress"][0]["hostname"]
  end

  def kubecmd(cmd)
    ns = fetch(:kube_namespace)
    sh "kubectl --namespace #{ns} #{cmd}"
  end

end
