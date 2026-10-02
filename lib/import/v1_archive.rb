# Replaces everything in this install with one Runwell v1 tenant, from an archive of its database
# and files that someone uploaded here as a document. It's for an install with no shell to reach,
# run as a hosting task ("run now"); with a shell, `import:v1` on the unpacked files does the same.
#
#   bin/rails "import:v1_archive[acme-v1.tgz,replace]"        the archive's one tenant
#   bin/rails "import:v1_archive[acme-v1.tgz,replace,acme]"   a named tenant, when it holds several
#
# An archive too big to upload in one piece (Cloudflare refuses a request over 100 MB) goes up as
# parts named after it, from `split -b 95m acme-v1.tgz acme-v1.tgz.part-`: acme-v1.tgz.part-aa,
# .part-ab, … The task takes the archive's own name and joins the parts in order.
#
# The archive (.tgz) holds v1's tenants/production/<tenant>/main.sqlite3 and the tenant's file
# tree (<tenant>/ab/cd/…), for any tenant. In order: the archive is copied out of storage, every database is
# backed up (runwell:backup), the install is emptied (every table but Rails' own; staff, clients,
# settings and uploads included, so everyone signs in again), then Import::V1 runs and prints its
# report, and the copy is removed. "replace" must be passed: there's no undo but the backup.
require "fileutils"
require "sqlite3"

module Import
  class V1Archive
    KEEP_TABLES = %w[schema_migrations ar_internal_metadata].freeze

    def initialize(filename, tenant: nil, out: $stdout)
      @filename = filename.to_s
      @tenant = tenant.presence
      @out = out
    end

    def run
      blobs = uploaded_blobs

      work = File.join(File.expand_path(ENV.fetch("RUNWELL_DATA_DIR", "storage"), Rails.root), "import-#{Time.current.strftime("%Y%m%d%H%M%S")}")
      FileUtils.mkdir_p(work)
      archive = File.join(work, @filename)
      File.open(archive, "wb") do |file|
        blobs.each { |blob| File.open(blob.service.path_for(blob.key), "rb") { IO.copy_stream(it, file) } }
      end
      say "Copied #{@filename}#{" from #{blobs.size} parts" if blobs.many?} (#{(File.size(archive) / 1_048_576.0).round(1)} MB)"

      system("tar", "xzf", archive, "-C", work, exception: true)
      database = tenant_database(work)

      # Fold in anything still in the write-ahead log, so the import reads the latest data.
      SQLite3::Database.new(database) { it.execute("PRAGMA wal_checkpoint(TRUNCATE)") }

      say "Backing up every database"
      Rake::Task["runwell:backup"].invoke

      say "Emptying this install"
      empty_database
      blobs.each { FileUtils.rm_f(it.service.path_for(it.key)) }

      say "Importing #{File.basename(File.dirname(database))}"
      Import::V1.new(database, work, out: @out).run
    ensure
      FileUtils.rm_rf(work) if work
    end

    private

    # The archive uploaded whole, or else its parts (name.part-aa, name.part-ab, …) in order, the
    # latest upload of each. An upload whose file never arrived (a browser upload cut off, say by
    # Cloudflare's 100 MB limit) leaves a record with nothing behind it, and is passed over.
    def uploaded_blobs
      stored = ->(blob) { blob.service.exist?(blob.key) }

      whole = ActiveStorage::Blob.where(filename: @filename).order(created_at: :desc).find(&stored)
      return [ whole ] if whole

      parts = ActiveStorage::Blob.where("filename LIKE ?", "#{ActiveStorage::Blob.sanitize_sql_like(@filename)}.part-%").order(created_at: :desc).select(&stored)
      parts = parts.group_by { it.filename.to_s }.sort.map { |_name, blobs| blobs.first }
      raise "No uploaded file named #{@filename} or #{@filename}.part-aa, … Upload it as documents on any client first." if parts.empty?

      names = parts.map { it.filename.to_s.delete_prefix("#{@filename}.part-") }
      expected = ("aa"..).first(names.size)
      raise "#{@filename} is missing part #{(expected - names).first || names.last.succ}: upload every part (it has #{names.to_sentence})." unless names == expected

      parts
    end

    # The named tenant's database, or the archive's only one.
    def tenant_database(work)
      databases = Dir[File.join(work, "tenants", "*", "*", "main.sqlite3")]
      names = databases.map { File.basename(File.dirname(it)) }
      raise "#{@filename} has no tenants/production/<tenant>/main.sqlite3 in it." if databases.empty?

      if @tenant
        databases[names.index(@tenant) || raise("#{@filename} has no tenant #{@tenant} (it has #{names.to_sentence}).")]
      elsif databases.one?
        databases.first
      else
        raise "#{@filename} holds #{names.to_sentence}: name the one to import as the third argument."
      end
    end

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
