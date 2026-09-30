# Invoices: every mirrored one (index), and invoicing a fixed-price engagement from Runwell.
module Quickbooks
  class InvoicesController < ApplicationController
    allow_staff only: :index
    require_permission :manage_billing, only: :create
    agent_tool :list_invoices, on: :index, title: "List QuickBooks invoices",
      params: { status: %w[open overdue all], client_id: "integer", engagement: "string" },
      description: "Invoices mirrored from QuickBooks, newest first. engagement: a ref."
    agent_tool :invoice_work, on: :create, title: "Invoice a work order (in full, or a deposit)",
      description: "portion full: everything approved and not yet invoiced. portion deposit: percent of the agreed amount, or amount_cents; send_balance_on_close then sends the rest to the same contact when the work order is closed. QuickBooks emails the invoice with its pay link to contact_id.",
      params: { invoice: { portion: WorkOrderBilling::PORTIONS, percent: "number", amount_cents: "integer", contact_id: "integer!", send_balance_on_close: "boolean" } },
      confirm: "QuickBooks will create this invoice in your books and email it, with a pay link, to the contact."

    def index
      scope = Invoice.includes(:client, :engagement).recent
      scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
      scope = scope.where(engagement: ::Engagement.find_by_ref!(params[:engagement])) if params[:engagement].present?
      @status = params[:status].presence_in(%w[open overdue all]) || "open"
      scope = @status == "all" ? scope : scope.public_send(@status)
      @invoices = scope.limit(100)
    end

    def create
      set_engagement
      attributes = params.expect(invoice: %i[portion percent amount_cents contact_id send_balance_on_close])
      contact = @engagement.client.contacts.find_by(id: attributes[:contact_id])
      invoice = WorkOrderBilling.new(@engagement).invoice!(portion: attributes[:portion], contact: contact, percent: attributes[:percent],
        amount_cents: attributes[:amount_cents], send_balance_on_close: ActiveModel::Type::Boolean.new.cast(attributes[:send_balance_on_close]))
      redirect_to engagement_path(@engagement), notice: "#{invoice.label} for #{money(invoice.total_cents)} sent to #{invoice.sent_to}#{invoice.payment_link ? " with a pay link" : ""}."
    rescue ArgumentError, Api::Error => e
      redirect_to engagement_path(@engagement), alert: e.message
    end

    private
      def money(cents) = Money.format(cents)
  end
end
