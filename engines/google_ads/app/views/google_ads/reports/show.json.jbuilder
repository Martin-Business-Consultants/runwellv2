totals = @report.totals
json.summary "#{@link.label}, #{@report.month_name}: #{money(totals[:cost_cents])} spend, #{totals[:conversions].round(1)} leads"
json.engagement agent_ref(@engagement)
json.account({ customer_id: @link.formatted_customer_id, label: @link.label, stopped: @report.account&.blocked? || false })
json.month @report.month.strftime("%Y-%m")
json.months(@report.available_months.map { it.strftime("%Y-%m") })
json.compared_with @report.comparison_label
json.totals(totals.except(:days).transform_values { it.is_a?(Float) ? it.round(4) : it })
json.changes(%i[cost_cents conversions cost_per_conversion_cents clicks impressions click_through_rate cost_per_click_cents conversion_rate search_impression_share].to_h { [ it, @report.change_in(it)&.round(4) ] })
json.days(@report.series.map { it.except(:label, :full_label) })
json.monthly(@report.monthly_trend.map { it.except(:label) })
