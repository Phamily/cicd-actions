class GitModule

  def prepare
    set :git_tags, (ENV['INPUT_GIT_TAGS'] || "").split(",")
    set :git_tag, ENV['INPUT_GIT_TAG']
    set :git_tag_suffix, ENV['INPUT_GIT_TAG_SUFFIX']
  end

  def skip_if_tagged
    # get tags for commit
    sha = fetch(:github_sha)
    sha_tags = `git tag --points-at #{sha}`.split("\n")
    puts "Current sha tags: #{sha_tags.join(", ")}"
    git_tags = fetch(:git_tags)
    should_skip = sha_tags.any?{|tag|
      git_tags.include?(tag)
    }
    if should_skip
      puts "Tag found, notifying to skip."
    end
    puts "::set-output name=skip::#{should_skip}"
  end

  def tag
    sha = fetch(:github_sha)
    tag = fetch(:git_tag)
    sfx = fetch(:git_tag_suffix)
    raise "Tag not specified" if !present?(tag)

    sh("git tag -fa #{tag} #{sha} -m \"Release #{tag}\"")

    if sfx == "date"
      dnow = Time.now.strftime("%Y%m%d")
      dtag = "#{tag}-#{dnow}"
      sh("git tag -fa #{dtag} #{sha} -m \"Release #{dtag}\"")
    end


    actor = fetch(:github_actor)
    sh("git config user.name #{actor}")
    sh("git config user.email #{actor}@users.noreply.github.com")
    sh("git push origin --tags")
  end

end