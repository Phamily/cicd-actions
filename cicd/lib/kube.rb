class KubeModule

  def prepare
    set :kube_cluster_name, ENV['INPUT_KUBE_CLUSTER_NAME']
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
        apply_environment(e)
      end
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

  def apply_environment(e)
    puts "Applying to the #{e["name"]} environment."
    build_vars(e)
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
      write_template_file("/kube/#{cm}.yml.erb", manifest, context: ctx)
      puts File.read(manifest)
      comp["build_manifest"] = manifest
    end

    puts "Updating service components."
    svcs.each do |c|
      next if c["skip"] == true
      puts "Updating service: #{c["name"]}"
      kubecmd "apply -f #{c["build_manifest"]}"
      # wait for finished
      wait_for_resource("deployment", c["name"])
    end

    puts "Running job components."
    jobs.each do |c|
      next if c["skip"] == true
      puts "Running init: #{c["name"]}"
      # delete previous job if present
      kubecmd "delete job #{c["name"]} --ignore-not-found"
      # run job
      kubecmd "apply -f #{c["build_manifest"]}"
      # wait for finished
      wait_for_resource("job", c["name"])
      # get logs
      kubecmd "logs job/#{c["name"]}"
    end

    puts "Updating deployment components."
    kubecmd "apply #{apps.select{|c| c["skip"] != true}.map{|c| "-f #{c["build_manifest"]}"}.join(" ")}"
  end

  def wait_for_resource(type, name, opts={})
    type = type.to_s
    timeout = opts[:timeout] || 300
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

  def kubecmd(cmd)
    ns = fetch(:kube_namespace)
    sh "kubectl --namespace #{ns} #{cmd}"
  end

end
