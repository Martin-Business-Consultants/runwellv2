# Backups of the databases before an update migrates them (Runwell::Backup). In production,
# db:migrate and db:prepare (which the Docker image runs on boot, and bin/update runs) first copy
# every database that has migrations to run. A failed copy stops the migration.
#
#   bin/rails runwell:backup                  # every database, now
#   RUNWELL_BACKUP_BEFORE_MIGRATE=false       # skip the automatic one
#   RUNWELL_BACKUPS_KEEP=5                    # how many backups to keep (oldest go first)
namespace :runwell do
  desc "Back up every database to RUNWELL_DATA_DIR/backups"
  task backup: :environment do
    Runwell::Backup.run
  end

  task backup_before_migrate: "db:load_config" do
    if Rails.env.production? && ENV["RUNWELL_BACKUP_BEFORE_MIGRATE"] != "false"
      Rake::Task["environment"].invoke
      Runwell::Backup.run(only_pending: true)
    end
  end
end

Rake::Task["db:migrate"].enhance([ "runwell:backup_before_migrate" ])
Rake::Task["db:prepare"].enhance([ "runwell:backup_before_migrate" ])
