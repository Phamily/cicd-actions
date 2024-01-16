class GitModule

  def prepare
    set :git_tags, (ENV['INPUT_GIT_TAGS'] || "").split(",")
    set :git_tag, ENV['INPUT_GIT_TAG']
    set :git_tag_suffix_method, ENV['INPUT_GIT_TAG_SUFFIX_METHOD']
    set :git_pat, ENV['INPUT_GIT_PAT']
    set :git_pat_username, ENV['INPUT_GIT_PAT_USERNAME']
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
    sfx = fetch(:git_tag_suffix_method) 
  
    raise "Tag not specified" if !present?(tag)
    
    github_repository = fetch(:github_repository)
    actor = fetch(:github_actor)
    git_pat = fetch(:git_pat)
    git_pat_username = fetch(:git_pat_username)
    remote = "origin"

    if git_pat
      sh("git remote set-url #{remote} https://#{git_pat}@github.com/#{github_repository}.git")
    end
    sh("git config --global user.name #{actor}")
    sh("git config --global user.email #{actor}@users.noreply.github.com")
    
    # Always push the tag that you receive
    sh("git tag -fa #{tag} #{sha} -m \"Release #{tag}\"")
    sh("git push -f #{remote} #{tag}")
    
    # If sfx method is specified, tag & push a uniq copy
    if sfx
      uniq_tag = uniq_sfx(tag, sfx)
      sh("git tag -fa #{uniq_tag} #{sha} -m \"Release #{uniq_tag}\"")
      sh("git push -f #{remote} #{uniq_tag}")
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
