# A service's recurring invoice in QuickBooks: create one from the agreement or link an
# existing one (create), bring it into step now (update), or let go of it (destroy).
module Quickbooks
  class RecurringController < ApplicationController
    require_permission :manage_billing
    agent_tool :link_recurring_invoice, on: :create, title: "Give a service a recurring invoice in QuickBooks",
      description: "With qbo_id, links an existing recurring invoice (it must bill this client’s customer). Without, creates one billing the approved amount on the approved cadence from start_on, which QuickBooks emails to contact_id each period.",
      params: { recurring: { qbo_id: "string", start_on: "date", contact_id: "integer" } },
      confirm: "QuickBooks will bill the client on this schedule and email each invoice, with a pay link, to the contact."
    agent_tool :sync_recurring_invoice, on: :update, title: "Bring a service’s recurring invoice into step with its agreement now",
      description: "Sets QuickBooks to the approved amount and cadence, and stops it if the service is closed. It already happens on approval and on close."
    agent_tool :unlink_recurring_invoice, on: :destroy, title: "Unlink a service’s recurring invoice",
      description: "Only unlinks: QuickBooks keeps billing until it’s stopped there or the service is closed first."

    before_action :set_engagement

    def create
      attributes = params.expect(recurring: %i[qbo_id start_on contact_id])
      billing = RecurringBilling.new(@engagement)
      link = if attributes[:qbo_id].present?
        billing.link!(attributes[:qbo_id])
      else
        billing.create!(contact: @engagement.client.contacts.find_by(id: attributes[:contact_id]), start_on: attributes[:start_on].presence || Date.current.next_month.beginning_of_month)
      end
      redirect_to engagement_path(@engagement), notice: "#{link.name} bills #{Money.format(link.amount_cents)} #{link.schedule_label}#{link.in_sync? ? "" : ". It doesn’t match the agreement: #{link.drift}"}."
    rescue ArgumentError, Api::Error => e
      redirect_to engagement_path(@engagement), alert: e.message
    end

    def update
      link = RecurringBilling.new(@engagement).push! or return redirect_to(engagement_path(@engagement), alert: "This service has no recurring invoice.")
      redirect_to engagement_path(@engagement), notice: "QuickBooks bills #{Money.format(link.amount_cents)} #{link.schedule_label}#{link.active ? "" : " and has stopped"}."
    rescue ArgumentError, Api::Error => e
      redirect_to engagement_path(@engagement), alert: e.message
    end

    def destroy
      RecurringLink.find_by(engagement: @engagement)&.destroy!
      @engagement.record_event!("quickbooks.recurring_unlinked")
      redirect_to engagement_path(@engagement), notice: "Unlinked. QuickBooks keeps billing it until it’s stopped there."
    end
  end
end
