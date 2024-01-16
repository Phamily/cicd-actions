class GitModule

  def prepare
    set :git_tags, (ENV['INPUT_GIT_TAGS'] || "").split(",")
    set :git_tag, ENV['INPUT_GIT_TAG']
    set :git_tag_suffix, ENV['INPUT_GIT_TAG_SUFFIX']
    set :git_pat, ENV['INPUT_GIT_PAT']
    set :git_pat_user, ENV['INPUT_GIT_PAT_USER']
  end

  def skip_if_tagged
    # get tags for commit
    sha = fetch(:github_sha)
    sha_tags = `git tag --points-at #{sha}`.split("\n")
    puts "Current sha tags: #{sha_tags.join(", ")}"
    check_tag = fetch(:git_tag)
    should_skip = sha_tags.any?{|tag|
      tag.include?(check_tag)
    }
    if should_skip
      puts "Tag found, notifying to skip."
    end
    puts "::set-output name=skip::#{should_skip}"
  end

  def tag
    sha = fetch(:github_sha)
    tag = fetch(:git_tag)
    sfx = fetch(:uniq_sfx_method) 
  
    raise "Tag not specified" if !present?(tag)
    
    github_action_repository = fetch(:github_action_repository)
    actor = fetch(:github_actor)
    
    sh("git remote set-url origin https://#{git_pat_user_name}:#{git_pat}@github.com/#{github_action_repository}")
    sh("git config --global user.name #{actor}")
    sh("git config --global user.email #{actor}@users.noreply.github.com")
    
    # Always push the tag that you receive
    sh("git tag -fa #{tag} #{sha} -m \"Release #{tag}\"")
    sh("git push -f origin #{tag}")
    
    # If sfx method is specified, tag & push a uniq copy
    if sfx
      uniq_tag = uniq_sfx(tag, sfx)
      sh("git tag -fa #{uniq_tag} #{sha} -m \"Release #{uniq_tag}\"")
      sh("git push -f origin #{uniq_tag}")
    end
  end

  def uniq_sfx(tag, type)
    if type == "date"
      dnow = Time.now.strftime("%Y%m%d-%H%M")
      return "#{tag}-#{dnow}"
    end
    
    raise "Tag uniq method not found"
  end

end
