# Installed plugins live in plugins/, one directory per plugin, each a gem with a gemspec that
# the Gemfile picks up. Installing clones a git repository there, bundles, migrates and asks
# Puma to restart. Bundled plugins (engines/) ship with the core and are never touched here.
namespace :plugins do
  desc "List every plugin: bundled and installed, version, on or off"
  task list: :environment do
    Runwell::Plugins.manifests.values.sort_by(&:name).each do |plugin|
      state = Runwell::Plugins.enabled?(plugin.key) ? "on " : "off"
      source = plugin.bundled ? "bundled" : "plugins/#{plugin.key}"
      note = plugin.compatible? ? "" : "  (needs Runwell #{plugin.requires}; this is #{Runwell::VERSION})"
      puts "#{state}  #{plugin.name.ljust(24)} #{plugin.version.ljust(8)} #{source}#{note}"
    end
  end

  desc "Install a plugin from a git URL, optionally at a tag or branch: bin/rails \"plugins:install[https://github.com/org/runwell-thing,v1.2.0]\""
  task :install, [ :url, :ref ] do |_task, args|
    url = args[:url].presence or abort "Usage: bin/rails \"plugins:install[https://github.com/org/plugin]\""
    name = File.basename(url.sub(/\.git\z/, ""))
    directory = plugins_directory.join(name)
    abort "#{directory} already exists. To update it: bin/rails \"plugins:update[#{name}]\"" if directory.exist?

    branch = args[:ref].present? ? [ "--branch", args[:ref] ] : []
    run! "git", "clone", "--depth", "1", *branch, url, directory.to_s
    abort "#{name} isn't a Runwell plugin: no gemspec in #{directory}" if Dir.glob(directory.join("*.gemspec")).none?

    apply_plugin_changes!
    puts "\nInstalled #{name}. Switch it on in Settings > Plugins."
  end

  desc "Pull the latest version of an installed plugin (all of them with no name): bin/rails \"plugins:update[name]\""
  task :update, [ :name ] do |_task, args|
    directories = args[:name].present? ? [ plugins_directory.join(args[:name]) ] : plugins_directory.glob("*").select(&:directory?)
    abort "Nothing installed in #{plugins_directory}" if directories.none?

    directories.each do |directory|
      abort "No plugin at #{directory}" unless directory.join(".git").exist?
      puts "== #{directory.basename} =="
      run! "git", "-C", directory.to_s, "pull", "--ff-only"
    end
    apply_plugin_changes!
  end

  desc "Remove an installed plugin's code (its tables stay): bin/rails \"plugins:remove[name]\""
  task :remove, [ :name ] do |_task, args|
    directory = plugins_directory.join(args[:name].to_s)
    abort "No plugin at #{directory}" unless args[:name].present? && directory.join(".git").exist?

    directory.rmtree
    apply_plugin_changes!
    puts "\nRemoved #{args[:name]}. Its tables are still in the database, so reinstalling brings the data back."
  end

  def plugins_directory = Rails.root.join("plugins")

  def run!(*command)
    puts "  $ #{command.join(" ")}"
    system(*command, exception: true)
  end

  # The Gemfile changed, so bundle and migrate in fresh processes. Puma's tmp_restart plugin
  # picks up the touch; a Docker install rebuilds its image instead.
  def apply_plugin_changes!
    Bundler.with_unbundled_env do
      run! "bundle", "install"
      run! "bin/rails", "db:migrate"
      run! "bin/rails", "assets:precompile" if ENV["RAILS_ENV"] == "production"
    end
    FileUtils.touch Rails.root.join("tmp/restart.txt")
  end
end
