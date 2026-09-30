json.summary "#{@invoices.size} #{@status} #{"invoice".pluralize(@invoices.size)}, #{money @invoices.sum(&:balance_cents)} outstanding"
json.invoices @invoices do |invoice|
  json.id invoice.id
  json.qbo_id invoice.qbo_id
  json.extract! invoice, :kind, :doc_number, :txn_date, :due_on, :total_cents, :balance_cents, :status, :payment_link, :sent_to, :sent_at
  json.total money(invoice.total_cents)
  json.balance money(invoice.balance_cents)
  json.client agent_ref(invoice.client)
  json.engagement agent_ref(invoice.engagement)
end
