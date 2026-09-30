json.period @period.name
json.from @period.from
json.to @period.to
if @financials.nil?
  json.summary "No report: switch on and connect the QuickBooks plugin."
else
  financials = @financials
  pnl = financials.profit_and_loss
  json.summary "#{@period.label}: billed #{money financials.billed_cents}, collected #{money financials.collected_cents}, #{money financials.outstanding_cents} owed (#{money financials.overdue_cents} overdue), #{money financials.monthly_recurring_cents}/month recurring#{pnl.available? ? ", net income #{money pnl[:net_income]}" : ""}"
  json.billed_cents financials.billed_cents
  json.collected_cents financials.collected_cents
  json.outstanding_cents financials.outstanding_cents
  json.overdue_cents financials.overdue_cents
  json.monthly_recurring_cents financials.monthly_recurring_cents
  json.monthly_recurring_billed_cents financials.monthly_recurring_billed_cents
  json.by_month(financials.by_month.map { it.slice(:full_label, :billed, :collected).transform_keys(billed: :billed_cents, collected: :collected_cents, full_label: :month) })
  json.aging(financials.aging.map { { bucket: it[:label], cents: it[:cents], invoices: it[:count] } })
  json.profit_and_loss(pnl.available? ? pnl.totals.transform_keys { "#{it}_cents" }.merge("expense_lines" => pnl.expense_lines, "income_lines" => pnl.income_lines) : { "error" => pnl.error })
  json.recurring financials.recurring do |row|
    json.engagement agent_ref(row[:engagement])
    json.amount_cents row[:amount]
    json.cadence row[:cadence]
    json.monthly_cents row[:monthly]
    json.state row[:state]
    json.drift row[:link]&.drift
  end
  json.unbilled financials.unbilled do |row|
    json.engagement agent_ref(row[:engagement])
    json.agreed_cents row[:agreed]
    json.invoiced_cents row[:invoiced]
    json.remaining_cents row[:agreed] - row[:invoiced]
  end
  json.by_client financials.by_client do |row|
    json.client agent_ref(row[:client])
    json.billed_cents row[:billed]
    json.collected_cents row[:collected]
    json.owed_cents row[:owed]
  end
end
