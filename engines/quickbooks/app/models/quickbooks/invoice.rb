module Quickbooks
  # An invoice as QuickBooks holds it, mirrored for a linked customer. Runwell's own invoices
  # (a work order's full, deposit or balance invoice) carry their engagement; others arrive
  # from the sync with none. Status is read off the balance, never typed in.
  class Invoice < ::ApplicationRecord
    self.table_name = "quickbooks_invoices"

    KINDS = %w[full deposit balance recurring other].freeze
    # Put on every invoice Runwell creates, so the sync can tell which engagement it was for.
    MEMO = "Runwell engagement "

    belongs_to :client, class_name: "::Client"
    belongs_to :engagement, class_name: "::Engagement", optional: true
    belongs_to :created_by, class_name: "::User", optional: true
    has_many :payments, dependent: :destroy

    validates :kind, inclusion: { in: KINDS }

    scope :live, -> { where(voided: false) }
    scope :open, -> { live.where("balance_cents > 0") }
    scope :overdue, -> { open.where("due_on < ?", Date.current) }
    scope :recent, -> { order(txn_date: :desc, id: :desc) }
    scope :billed, -> { live.where(kind: %w[full deposit balance]) }

    def status
      return "voided" if voided
      return "paid" if balance_cents <= 0
      return "overdue" if due_on && due_on < Date.current
      return "partly paid" if balance_cents < total_cents

      "open"
    end

    def paid_cents = total_cents - balance_cents
    def label = [ kind == "other" ? "Invoice" : "#{kind.humanize} invoice", doc_number && "##{doc_number}" ].compact.join(" ")
    def days_overdue = due_on && due_on < Date.current ? (Date.current - due_on).to_i : 0
  end
end
