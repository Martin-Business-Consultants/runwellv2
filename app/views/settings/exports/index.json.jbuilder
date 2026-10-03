json.summary @exports.any? ? "#{@exports.size} exports, newest first" : "No exports yet: create_export makes one."
json.exports @exports do |export|
  json.extract! export, :id, :state, :tables_count, :rows_count, :files_count, :error, :created_at, :completed_at
  json.by export.user.display_name
  json.download_url(export.ready? && export.archive.attached? ? rails_blob_url(export.archive, disposition: "attachment") : nil)
end
