# Backups of the databases, taken before an update migrates them (lib/tasks/backup.rake). Each is
# a folder in RUNWELL_DATA_DIR/backups named for the time and the version that made it, holding a
# consistent copy of each database (SQLite's VACUUM INTO, safe while the app runs). Uploaded files
# aren't copied: Active Storage never changes a stored file.
#
# To restore: stop Runwell, copy the files back over the ones in RUNWELL_DATA_DIR, and run the
# version the folder names.
module Runwell::Backup
  extend self

  # A connection of its own per database, so backing up never touches the app's.
  class Connection < ActiveRecord::Base
    self.abstract_class = true
  end

  # Every database, or only those with migrations to run. Returns the folder, or nil when there
  # was nothing to back up.
  def run(only_pending: false)
    configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).select { File.exist?(it.database.to_s) }
    configs = configs.select { pending?(it) } if only_pending
    return if configs.empty?

    folder = Runwell.data_dir.join("backups", "#{Time.now.utc.strftime("%Y%m%d-%H%M%S-%L")}-v#{Runwell::VERSION}")
    FileUtils.mkdir_p folder
    configs.each do |config|
      target = folder.join(File.basename(config.database))
      with_pool(config) { |pool| pool.with_connection { it.execute("VACUUM INTO #{it.quote(target.to_s)}") } }
      puts "Backed up #{config.name} to #{target}"
    end
    prune
    folder
  end

  private
    def pending?(config)
      with_pool(config) { it.migration_context.needs_migration? }
    end

    def with_pool(config)
      Connection.establish_connection(config)
      yield Connection.connection_pool
    ensure
      Connection.remove_connection
    end

    def prune
      keep = Integer(ENV.fetch("RUNWELL_BACKUPS_KEEP", 5))
      Runwell.data_dir.join("backups").children.select(&:directory?).sort.reverse.drop(keep).each(&:rmtree)
    end
end
