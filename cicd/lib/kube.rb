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
    cicd = fetch(:cicd_config)
    cicd["environments"].each do |e|
      if e["branch"] == branch
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
    build_vars(e)
    # iterate needed manifests
    init_comps = []
    depl_comps = []
    cicdc = fetch(:cicd_config)
    e["kube"]["components"].each do |comp|
      next if comp["skip"] == true
      name = comp["name"]
      cm = comp["manifest"] || comp["name"]
      manifest = "/kube/build/#{name}.yml"
      puts "Building manifest #{name}."
      ctx = merge_with_options(cicdc["defaults"], e["kube"], comp)
      write_template_file("/kube/#{cm}.yml.erb", manifest, context: ctx)
      puts File.read(manifest)
      comp["build_manifest"] = manifest
      if comp["init"]
        init_comps << comp
      else
        depl_comps << comp
      end
    end

    puts "Running init components."
    init_comps.each do |c|
      puts "Running init: #{c["name"]}"
      # delete previous job if present
      kubecmd "delete job #{c["name"]} --ignore-not-found"
      # run job
      kubecmd "apply -f #{c["build_manifest"]}"
      # wait for finished
      kubecmd "wait --for=condition=complete job/#{c["name"]}"
    end

    puts "Running deployment components."
    kubecmd "apply #{depl_comps.map{|c| "-f #{c["build_manifest"]}"}.join(" ")}"
  end

  def kubecmd(cmd)
    ns = fetch(:kube_namespace)
    sh "kubectl --namespace #{ns} #{cmd}"
  end

end
