# Settings > QuickBooks: the agency's Intuit app, signing in to the company, which product or
# service stands behind Runwell's invoice lines, and the last sync.
module Quickbooks
  class SettingsController < ApplicationController
    require_permission :manage_settings
    agent_tool :show_quickbooks_settings, on: :show, title: "Show the QuickBooks connection"
    agent_tool :update_quickbooks_settings, on: :update, title: "Change QuickBooks credentials and the invoice line item",
      description: "default_item_id: the QuickBooks product or service every Runwell invoice line uses (show_quickbooks_settings lists them).",
      params: { connection: { client_id: "string", client_secret: "string", environment: Connection::ENVIRONMENTS, default_item_id: "string" } }
    agent_tool :disconnect_quickbooks, on: :destroy, title: "Disconnect QuickBooks"

    before_action { @connection = Connection.for_settings }

    def show
      @items = items
      @customers = Customer.count
      @recurring = RecurringLink.count
    end

    def update
      attributes = connection_params
      if attributes[:default_item_id].present?
        attributes[:default_item_name] = items.find { it["Id"] == attributes[:default_item_id] }&.dig("Name")
      end
      if @connection.update(attributes)
        redirect_to quickbooks_settings_path, notice: @connection.connected? ? "Saved." : "Saved. Now sign in with QuickBooks to connect."
      else
        redirect_to quickbooks_settings_path, alert: @connection.errors.full_messages.to_sentence
      end
    end

    def destroy
      Oauth.new(@connection).revoke!
      @connection.disconnect!
      redirect_to quickbooks_settings_path, notice: "Disconnected from QuickBooks. Mirrored invoices stay; nothing changes in QuickBooks."
    end

    private
      # The secret is write-only on the page: a blank field keeps what is saved.
      def connection_params
        params.expect(connection: %i[client_id client_secret environment default_item_id])
          .reject { |key, value| key == "client_secret" && value.blank? }
      end

      # The products and services invoice lines can use, asked of QuickBooks (which also
      # proves the connection works).
      def items
        return [] unless @connection.connected?

        @items_list ||= Api.new(@connection).items.sort_by { it["Name"].to_s.downcase }
      rescue Api::Error => e
        @connection.note_error!(e.message)
        []
      end
  end
end
