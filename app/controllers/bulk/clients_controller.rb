# Clients, many at once: their status, or delete (only those with no work).
class Bulk::ClientsController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :bulk_update_clients, on: :update, title: "Change several clients' status at once",
    description: "Dormant or former closes each one's open work as cancelled and marks its open tasks done; active again reopens nothing.",
    params: { ids: "integer[]!", client: { status: Client::STATUSES } }
  agent_tool :bulk_delete_clients, on: :destroy, title: "Delete several clients at once",
    description: "Only clients with no work are deleted; the rest are skipped and named.", params: { ids: "integer[]!" }

  def update
    status = params.expect(client: [ :status ])[:status]
    sunset = status.present? && status != "active" ? ", closing their open #{Setting.current.term(:work, count: 2).downcase} and #{Setting.current.term(:task, count: 2).downcase}" : ""
    apply_to_each(selected(Client.all), done: "Marked %{count} #{noun} #{status.to_s.humanize.downcase}#{sunset}", fallback: clients_path) do |client|
      client.update(status: status) || client.errors.full_messages.to_sentence
    end
  end

  def destroy
    apply_to_each(selected(Client.all), done: "Deleted %{count} #{noun}", fallback: clients_path) do |client|
      client.destroy ? true : "it has work"
    end
  end

  private
    def noun = Setting.current.term(:client, count: 2).downcase
end
