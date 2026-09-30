# A client's QuickBooks customer: link an existing one by id, create one from the client, or
# let go of the link.
module Quickbooks
  class CustomersController < ApplicationController
    require_permission :manage_billing
    agent_tool :link_quickbooks_customer, on: :create, title: "Link a client to a QuickBooks customer",
      description: "customer.qbo_id: an existing customer’s id. Leave it out to create a customer in QuickBooks from the client (and email, if given).",
      params: { customer: { qbo_id: "string", email: "string" } }
    agent_tool :unlink_quickbooks_customer, on: :destroy, title: "Unlink a client from its QuickBooks customer",
      description: "Only unlinks. Nothing changes in QuickBooks."

    before_action { @client = ::Client.find(params[:client_id]) }

    def create
      attributes = params.fetch(:customer, {}).permit(:qbo_id, :email)
      api = Api.new
      payload = if attributes[:qbo_id].present?
        api.customers.find { it["Id"] == attributes[:qbo_id].to_s.strip } or raise Api::Error, "QuickBooks has no active customer #{attributes[:qbo_id]}."
      else
        api.create_customer({ "DisplayName" => @client.name, "CompanyName" => @client.name,
          "PrimaryEmailAddr" => (attributes[:email].presence && { "Address" => attributes[:email] }) }.compact)
      end
      customer = Customer.create!(client: @client, qbo_id: payload["Id"], display_name: payload["DisplayName"], email: payload.dig("PrimaryEmailAddr", "Address"))
      @client.record_event!("quickbooks.customer_linked", payload: { customer: customer.display_name })
      redirect_back fallback_location: @client, notice: "#{@client.name} is #{customer.display_name} in QuickBooks."
    rescue Api::Error, ActiveRecord::RecordInvalid => e
      redirect_back fallback_location: @client, alert: e.message
    end

    def destroy
      Customer.for(@client)&.destroy!
      redirect_back fallback_location: @client, notice: "Unlinked #{@client.name} from QuickBooks."
    end
  end
end
