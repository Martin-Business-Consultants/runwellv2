require "csv"

# Everything this install holds, as one .zip an owner downloads (Settings > Export, or the
# create_export tool). Two kinds:
#
# - data: every table, the core's and installed plugins', as JSON and CSV, and every stored file.
#   Secrets stay out: sign-in sessions, tokens, OAuth grants and the search index are skipped, and
#   columns holding passwords, secrets, tokens or keys are left out of every table.
# - backup: the database itself (a consistent copy, SQLite's VACUUM INTO) and every stored file
#   where Active Storage keeps it, with a manifest: what Runwell Go's Settings > Import (or
#   `runwell import`) restores, people's passwords included. It holds every secret the install
#   does, so treat it like the server's own disk.
#
# Built in a job (ExportJob); kept for a week.
class Export < ApplicationRecord
  KINDS = %w[data backup].freeze
  # queued until its job starts, working while it builds, then ready (to download) or failed.
  STATES = %w[queued working ready failed].freeze
  BACKUP_FORMAT = "runwell-backup"
  KEEP_FOR = 7.days
  SKIPPED_TABLES = %w[
    schema_migrations ar_internal_metadata sessions access_tokens oauth_clients oauth_grants portal_sessions
    approval_links invitations agent_calls agent_idempotency_keys
    searchable_documents active_storage_variant_records action_mailbox_inbound_emails plugin_changes upgrades exports
    pending_removals push_subscriptions
  ].freeze
  SECRET_COLUMNS = /password|secret|token|_digest\z|\Aotp_|credential|api_key|private_key|recovery/i

  belongs_to :user
  has_one_attached :archive

  validates :kind, inclusion: { in: KINDS }
  validates :state, inclusion: { in: STATES }

  scope :ordered, -> { order(created_at: :desc) }
  scope :expired, -> { where(created_at: ...KEEP_FOR.ago) }

  def self.expire_old! = expired.find_each(&:destroy!)

  def ready? = state == "ready"
  def failed? = state == "failed"
  def backup? = kind == "backup"
  def filename = "runwell-#{backup? ? "backup" : "export"}-#{created_at.strftime("%Y-%m-%d-%H%M")}.zip"

  def build!
    update!(state: "working")
    Tempfile.create([ "runwell-export", ".zip" ], binmode: true) do |file|
      counts = backup? ? write_backup_zip(file.path) : write_zip(file.path)
      archive.attach(io: File.open(file.path), filename: filename, content_type: "application/zip")
      update!(state: "ready", completed_at: Time.current, **counts)
    end
    ExportMailer.with(export: self).ready.deliver_later
  rescue => error
    update_columns(state: "failed", error: error.message.truncate(250))
    raise
  end

  private
    # The blobs a .zip carries: every stored file but exports' own archives.
    def stored_blobs = ActiveStorage::Blob.joins(:attachments).where.not(active_storage_attachments: { record_type: "Export" }).distinct

    # The backup: manifest.json, the database as production.sqlite3, and each file at
    # storage/<key[0,2]>/<key[2,2]>/<key>, the Disk service's own layout, so restoring is putting
    # them back where they were.
    def write_backup_zip(path)
      connection = self.class.connection
      tables = (connection.tables - %w[schema_migrations ar_internal_metadata]).sort
      rows = tables.sum { connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(it)}").to_i }
      files = 0

      Dir.mktmpdir("runwell-backup") do |dir|
        database = File.join(dir, "production.sqlite3")
        connection.execute("VACUUM INTO #{connection.quote(database)}")

        Zip::OutputStream.open(path) do |zip|
          zip.put_next_entry("README.txt")
          zip.write(backup_readme)

          zip.put_next_entry("production.sqlite3")
          File.open(database, "rb") { |db| IO.copy_stream(db, zip) }

          stored_blobs.find_each do |blob|
            zip.put_next_entry("storage/#{blob.key[0, 2]}/#{blob.key[2, 2]}/#{blob.key}")
            blob.download { |chunk| zip.write(chunk) }
            files += 1
          rescue ActiveStorage::FileNotFoundError
            next
          end

          zip.put_next_entry("manifest.json")
          zip.write(JSON.pretty_generate(format: BACKUP_FORMAT, format_version: 1, runwell_version: Runwell::VERSION,
            created_at: Time.current.utc.iso8601, host: Runwell.url, by: user.email_address,
            database: "production.sqlite3", tables: tables.size, rows: rows, files: files))
        end
      end

      { tables_count: tables.size, rows_count: rows, files_count: files }
    end

    def backup_readme
      <<~TEXT
        #{Setting.current.brand_name}: a backup of Runwell, made #{Time.current.to_fs(:long)} by #{user.display_name}.

        production.sqlite3   the database, every table, as it was (a consistent copy).
        storage/             every stored file, where Active Storage keeps it (<key[0,2]>/<key[2,2]>/<key>).
        manifest.json        what this is, and the version that made it.

        Restore it in Runwell Go with Settings > Import, or `runwell import <this file>`. It replaces
        everything there, and people sign in with their passwords from here.

        It holds every secret this install does: passwords (hashed), sign-in sessions, tokens and
        settings. Keep it as safe as the server itself.
      TEXT
    end

    def write_zip(path)
      connection = self.class.connection
      tables = (connection.tables - SKIPPED_TABLES).sort
      rows = 0
      files = 0

      Zip::OutputStream.open(path) do |zip|
        zip.put_next_entry("README.txt")
        zip.write(readme(tables))

        tables.each do |table|
          columns = connection.columns(table).map(&:name).grep_v(SECRET_COLUMNS)
          records = connection.select_all("SELECT #{columns.map { connection.quote_column_name(it) }.join(", ")} FROM #{connection.quote_table_name(table)}").to_a
          rows += records.size

          zip.put_next_entry("data/#{table}.json")
          zip.write(JSON.pretty_generate(records))
          zip.put_next_entry("data/#{table}.csv")
          zip.write(CSV.generate { |csv| csv << columns; records.each { |record| csv << record.values_at(*columns) } })
        end

        stored_blobs.find_each do |blob|
          zip.put_next_entry("files/#{blob.id}-#{blob.filename.sanitized}")
          blob.download { |chunk| zip.write(chunk) }
          files += 1
        rescue ActiveStorage::FileNotFoundError
          next
        end
      end

      { tables_count: tables.size, rows_count: rows, files_count: files }
    end

    def readme(tables)
      <<~TEXT
        #{Setting.current.brand_name}: everything in Runwell, exported #{Time.current.to_fs(:long)} by #{user.display_name}.

        data/   one table per file, as JSON (an array of rows) and CSV (a header row, then rows).
                Rows keep their ids, so records point at each other the way they do in Runwell:
                works.client_id is a clients.id, tasks.work_id an works.id, and so on.
                Tables named after a plugin (time_tracking_entries, …) are that plugin's.
        files/  every stored file (documents, images in rich text, the logo), named <blob id>-<name>.
                active_storage_attachments says which record each blob belongs to.

        Left out on purpose: sign-in sessions, tokens and OAuth grants, invitations, the search index,
        and every password, secret, token or key column. Times are UTC.

        Tables: #{tables.join(", ")}
      TEXT
    end
end
