module ApprovalsHelper
  # What the client saw: the frozen snapshot of a sent version. A version that was never sent
  # falls back to descriptions and prices only, so internal estimates never reach a client.
  def agreement_snapshot(version)
    version.snapshot.presence || {
      "engagement" => { "ref" => version.engagement.ref, "title" => version.engagement.title },
      "client" => version.engagement.client.name,
      "items" => version.scope_items.map { |item| { "description" => item.description, "price_cents" => item.price_cents } }
    }
  end

  def agreement_total_cents(version)
    version.kind.in?(%w[initial revision]) ? version.amount_cents : version.price_delta_cents
  end
end
