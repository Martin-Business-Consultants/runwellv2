# Settings > Export: everything this install holds as one .zip (Export), for owners. Making one
# runs in the background and emails when it's ready; each is kept for a week.
class Settings::ExportsController < Settings::BaseController
  agent_tool :list_exports, on: :index, title: "List exports",
    description: "Exports of everything (a .zip of every table as JSON and CSV, and every file), with their state and a download address when ready."
  agent_tool :create_export, on: :create, title: "Export everything",
    description: "Starts an export of all data and files as one .zip. It's built in the background: list_exports shows when it's ready.", next_tools: %w[list_exports]
  agent_tool :download_export, on: :show, title: "Download an export", description: "Answers with the address of a ready export's .zip."

  def index
    @exports = Export.ordered.includes(:user, archive_attachment: :blob)
  end

  def create
    export = Export.create!(user: Current.user)
    ExportJob.perform_later(export)
    Current.user.record_event!("user.exported", payload: { export: export.id })
    redirect_to settings_exports_path, notice: "Export started. It takes a minute or so; we’ll email #{Current.user.email_address} when it’s ready."
  end

  def show
    export = Export.find(params[:id])
    return redirect_to(settings_exports_path, alert: "That export isn’t ready.") unless export.ready? && export.archive.attached?

    redirect_to rails_blob_path(export.archive, disposition: "attachment")
  end
end
