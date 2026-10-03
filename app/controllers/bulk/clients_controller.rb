# Clients, many at once: their status, or delete (only those with no engagements).
class Bulk::ClientsController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :bulk_update_clients, on: :update, title: "Change several clients' status at once",
    params: { ids: "integer[]!", client: { status: Client::STATUSES } }
  agent_tool :bulk_delete_clients, on: :destroy, title: "Delete several clients at once",
    description: "Only clients with no engagements are deleted; the rest are skipped and named.", params: { ids: "integer[]!" }

  def update
    status = params.expect(client: [ :status ])[:status]
    apply_to_each(selected(Client.all), done: "Marked %{count} #{noun} #{status.to_s.humanize.downcase}", fallback: clients_path) do |client|
      client.update(status: status) || client.errors.full_messages.to_sentence
    end
  end

  def destroy
    apply_to_each(selected(Client.all), done: "Deleted %{count} #{noun}", fallback: clients_path) do |client|
      client.destroy ? true : "it has engagements"
    end
  end

  private
    def noun = Setting.current.term(:client, count: 2).downcase
end
