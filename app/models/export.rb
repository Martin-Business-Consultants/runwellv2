require "csv"

# Everything this install holds, as one .zip an owner downloads (Settings > Export, or the
# create_export tool): every table, the core's and installed plugins', as JSON and CSV, and every
# stored file. Secrets stay out: sign-in sessions, tokens, OAuth grants and the search index are
# skipped, and columns holding passwords, secrets, tokens or keys are left out of every table.
# Built in a job (ExportJob); kept for a week.
class Export < ApplicationRecord
  KEEP_FOR = 7.days
  SKIPPED_TABLES = %w[
    schema_migrations ar_internal_metadata sessions access_tokens oauth_clients oauth_grants portal_sessions
    approval_links invitations identities sign_in_providers agent_calls agent_idempotency_keys
    searchable_documents active_storage_variant_records action_mailbox_inbound_emails plugin_changes upgrades exports
  ].freeze
  SECRET_COLUMNS = /password|secret|token|_digest\z|\Aotp_|credential|api_key|private_key|recovery/i

  belongs_to :user
  has_one_attached :archive

  scope :ordered, -> { order(created_at: :desc) }
  scope :expired, -> { where(created_at: ...KEEP_FOR.ago) }

  def self.expire_old! = expired.find_each(&:destroy!)

  def ready? = state == "ready"
  def filename = "runwell-export-#{created_at.strftime("%Y-%m-%d-%H%M")}.zip"

  def build!
    update!(state: "working")
    Tempfile.create([ "runwell-export", ".zip" ], binmode: true) do |file|
      counts = write_zip(file.path)
      archive.attach(io: File.open(file.path), filename: filename, content_type: "application/zip")
      update!(state: "ready", completed_at: Time.current, **counts)
    end
    ExportMailer.with(export: self).ready.deliver_later
  rescue => error
    update_columns(state: "failed", error: error.message.truncate(250))
    raise
  end

  private
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

        ActiveStorage::Blob.joins(:attachments).where.not(active_storage_attachments: { record_type: "Export" }).distinct.find_each do |blob|
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
                engagements.client_id is a clients.id, todos.engagement_id an engagements.id, and so on.
                Tables named after a plugin (time_tracking_entries, …) are that plugin's.
        files/  every stored file (documents, images in rich text, the logo), named <blob id>-<name>.
                active_storage_attachments says which record each blob belongs to.

        Left out on purpose: sign-in sessions, tokens and OAuth grants, invitations, the search index,
        and every password, secret, token or key column. Times are UTC.

        Tables: #{tables.join(", ")}
      TEXT
    end
end
