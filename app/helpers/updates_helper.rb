module UpdatesHelper
  def update_method_description
    case Upgrade.via
    when "github" then "The Deploy workflow on GitHub (#{Release::Github.repo}#{", destination #{Upgrade::Github.destination}" if Upgrade::Github.destination.present?})"
    when "local" then "bin/update on this server"
    when "in_place" then "Itself: it downloads the release and restarts on it"
    else "Hand: updating from here isn’t set up"
    end
  end

  # What to run by hand when the button isn't set up: Kamal for a Docker install, else bin/update.
  def manual_update_command(release)
    if Rails.root.join(".git").exist?
      "bin/update #{release.tag}"
    else
      "git checkout #{release.tag} && bin/kamal deploy"
    end
  end
end
