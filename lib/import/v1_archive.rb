# Replaces everything in this install with one Runwell v1 tenant, from an archive of its database
# and files that someone uploaded here as a document. It's for an install with no shell to reach,
# run as a hosting task ("run now"); with a shell, `import:v1` on the unpacked files does the same.
#
#   bin/rails "import:v1_archive[brem-v1-import.tgz,replace]"
#
# The archive (.tgz) holds v1's tenants/production/<tenant>/main.sqlite3 and the tenant's file
# tree (<tenant>/ab/cd/…). In order: the archive is copied out of storage, every database is
# backed up (runwell:backup), the install is emptied (every table but Rails' own; staff, clients,
# settings and uploads included, so everyone signs in again), then Import::V1 runs and prints its
# report, and the copy is removed. "replace" must be passed: there's no undo but the backup.
require "fileutils"
require "sqlite3"

module Import
  class V1Archive
    KEEP_TABLES = %w[schema_migrations ar_internal_metadata].freeze

    def initialize(filename, out: $stdout)
      @filename = filename.to_s
      @out = out
    end

    def run
      blob = ActiveStorage::Blob.where(filename: @filename).order(created_at: :desc).first
      raise "No uploaded file named #{@filename}. Upload it as a document on any client first." unless blob

      work = File.join(File.expand_path(ENV.fetch("RUNWELL_DATA_DIR", "storage"), Rails.root), "import-#{Time.current.strftime("%Y%m%d%H%M%S")}")
      FileUtils.mkdir_p(work)
      archive = File.join(work, @filename)
      FileUtils.cp(blob.service.path_for(blob.key), archive)
      say "Copied #{@filename} (#{(File.size(archive) / 1_048_576.0).round(1)} MB)"

      system("tar", "xzf", archive, "-C", work, exception: true)
      database = Dir[File.join(work, "tenants", "*", "*", "main.sqlite3")].first
      raise "#{@filename} has no tenants/production/<tenant>/main.sqlite3 in it." unless database

      # Fold in anything still in the write-ahead log, so the import reads the latest data.
      SQLite3::Database.new(database) { it.execute("PRAGMA wal_checkpoint(TRUNCATE)") }

      say "Backing up every database"
      Rake::Task["runwell:backup"].invoke

      say "Emptying this install"
      empty_database
      FileUtils.rm_f(blob.service.path_for(blob.key))

      say "Importing #{File.basename(File.dirname(database))}"
      Import::V1.new(database, work, out: @out).run
    ensure
      FileUtils.rm_rf(work) if work
    end

    private

    # Every table but Rails' own, with foreign keys off. Full-text search tables are emptied
    # through the table itself, never their shadow tables, which would corrupt the index.
    def empty_database
      connection = ActiveRecord::Base.connection
      virtual = connection.select_values("SELECT name FROM sqlite_master WHERE type = 'table' AND sql LIKE 'CREATE VIRTUAL TABLE%'")
      tables = connection.tables.reject { |table| KEEP_TABLES.include?(table) || virtual.any? { table.start_with?("#{it}_") } }

      connection.disable_referential_integrity do
        ActiveRecord::Base.transaction do
          (tables | virtual).each { connection.execute("DELETE FROM #{connection.quote_table_name(it)}") }
        end
      end
      say "Emptied #{(tables | virtual).size} tables"
    end

    def say(line) = @out.puts(line)
  end
end
