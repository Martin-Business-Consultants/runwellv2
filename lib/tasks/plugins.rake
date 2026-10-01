# Plugins installed on this server live in RUNWELL_DATA_DIR/plugins (InstalledPlugins), put
# there from Settings > Plugins or by these tasks. Their migrations run after the core's, on
# every db:migrate and db:prepare, and their tables stay out of the core's schema.rb.
namespace :plugins do
  desc "List the plugins installed on this server: version, where from, on or off"
  task list: :environment do
    InstalledPlugins.present.each_key do |name|
      manifest = Runwell::Plugins.manifests[name.to_sym]
      state = manifest && Runwell::Plugins.enabled?(name) ? "on " : "off"
      source = InstalledPlugins.metadata(name)["repo"] || "linked by hand"
      note = InstalledPlugins.failed[name] ? "  (didn't load: #{InstalledPlugins.failed[name]})" : ""
      puts "#{state}  #{name.ljust(22)} #{InstalledPlugins.versions[name].to_s.ljust(8)} #{source}#{note}"
    end
    available = Runwell::PluginCatalog.available.map(&:key)
    puts "\nAvailable: #{available.join(", ")}" if available.any?
  end

  desc "Run installed plugins' migrations (db:migrate and db:prepare do it too)"
  task migrate: :environment do
    paths = InstalledPlugins.migration_paths
    if paths.any?
      pool = ActiveRecord::Base.connection_pool
      ActiveRecord::MigrationContext.new(paths, pool.schema_migration, pool.internal_metadata).migrate
    end
  end

  desc "Install a plugin's latest release from GitHub: bin/rails \"plugins:install[owner/repo]\" (or a key from config/plugins.yml)"
  task :install, [ :repo ] => :environment do |_task, args|
    repo = Runwell::PluginCatalog.find(args[:repo])&.repo || args[:repo]
    change = PluginChange.create!(action: "install", repo: repo)
    finish_plugin_change change
  end

  desc "Update an installed plugin to its latest release: bin/rails \"plugins:update[key]\""
  task :update, [ :key ] => :environment do |_task, args|
    change = PluginChange.create!(action: "update", key: args[:key], repo: PluginChange.installed_repo(args[:key]), from_version: InstalledPlugins.versions[args[:key]])
    finish_plugin_change change
  end

  desc "Remove an installed plugin's code (its tables stay): bin/rails \"plugins:remove[key]\""
  task :remove, [ :key ] => :environment do |_task, args|
    change = PluginChange.create!(action: "remove", key: args[:key], repo: PluginChange.installed_repo(args[:key]))
    finish_plugin_change change
  end

  desc "Link a plugin you're working on into this install: bin/rails \"plugins:link[../runwell-qa]\""
  task :link, [ :path ] do |_task, args|
    source = Pathname(File.expand_path(args[:path].to_s))
    gemspec = source.glob("*.gemspec").first or abort "No gemspec in #{source}: not a Runwell plugin."
    target = InstalledPlugins.directory.join(gemspec.basename(".gemspec").to_s)
    abort "#{target} already exists." if target.exist? || target.symlink?

    FileUtils.mkdir_p InstalledPlugins.directory
    File.symlink source, target
    puts "Linked #{source} as #{target.basename}. Restart Runwell and run bin/rails db:migrate."
  end

  def finish_plugin_change(change)
    abort change.message unless change.perform!(restart: false)
    puts "#{change.summary}: done. Restart Runwell to load it; it migrates on the way up (or run bin/rails db:migrate)."
  end
end

Rake::Task["db:migrate"].enhance { Rake::Task["plugins:migrate"].invoke }
Rake::Task["db:prepare"].enhance { Rake::Task["plugins:migrate"].invoke }
