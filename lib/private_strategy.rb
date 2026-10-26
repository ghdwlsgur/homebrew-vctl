# typed: false
# frozen_string_literal: true

require "download_strategy"
require "utils/github"

# Downloads a release asset from a private GitHub repository.
#
# The release's own download URL answers 404 without credentials, so the asset
# is looked up through the GitHub API with the credentials Homebrew already
# uses for GitHub — $HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else the
# keychain — and the API's short-lived signed URL is what curl downloads. The
# token is only sent to api.github.com; the download itself carries none.
class GitHubPrivateRepositoryReleaseDownloadStrategy < CurlDownloadStrategy
  URL_PATTERN = %r{\Ahttps://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/([^/]+)\z}

  def initialize(url, name, version, **meta)
    super
    match = URL_PATTERN.match(url)
    raise CurlDownloadStrategyError.new(url, "not a GitHub release asset URL") unless match

    @owner, @repo, @tag, @filename = match.captures
  end

  private

  def resolve_url_basename_time_file_size(url, timeout: nil)
    @signed_url ||= signed_asset_url
    [@signed_url, @filename, nil, nil, nil, true]
  end

  def signed_asset_url
    if GitHub::API.credentials_type == :none
      raise CurlDownloadStrategyError.new(url, <<~EOS)
        #{@owner}/#{@repo} is private: log in with `gh auth login`, or set
        HOMEBREW_GITHUB_API_TOKEN to a token that can read the repository.
      EOS
    end

    release = GitHub.get_release(@owner, @repo, @tag)
    asset = release.fetch("assets", []).find { |a| a["name"] == @filename }
    raise CurlDownloadStrategyError.new(url, "#{@filename} is not an asset of #{@owner}/#{@repo} #{@tag}") unless asset

    # The API answers with a redirect to the signed URL; read it, do not follow.
    result = curl_output("--silent", "--show-error", "--output", "/dev/null",
                         "--write-out", "%{http_code} %{redirect_url}",
                         "--header", "Accept: application/octet-stream",
                         *GitHub::API.credentials_curl_args,
                         "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset["id"]}")
    code, location = result.stdout.split(" ", 2)
    unless code.start_with?("3") && location.to_s.start_with?("https://")
      raise CurlDownloadStrategyError.new(url, "GitHub did not hand out a download URL for #{@filename} (HTTP #{code})")
    end

    location.strip
  rescue GitHub::API::HTTPNotFoundError
    raise CurlDownloadStrategyError.new(url, "#{@owner}/#{@repo} #{@tag} is not visible with your GitHub credentials")
  end
end
