# Whether agreements carry prices (Settings > Names): off hides money everywhere, price fields
# included, for an install that plans without it; on, an agreement shows money only where it has some.
class Settings::PricesController < Settings::BaseController
  agent_tool :update_prices, on: :update, title: "Turn prices on agreements on or off",
    description: "prices: false hides money everywhere (prices, totals, agreed amounts, price fields), for planning without it; true shows it wherever an agreement has some.",
    params: { setting: { prices: "boolean!" } }

  def update
    Setting.current.update!(prices: params.dig(:setting, :prices) == "1")
    redirect_to settings_names_path(anchor: "prices"), notice: Setting.current.prices? ? "Agreements show prices where they have them." : "Agreements no longer show prices."
  end
end
