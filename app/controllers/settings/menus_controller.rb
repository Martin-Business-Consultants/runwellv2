# Settings > Your account > Your menu: which plugins' links show in your nav, and in what order.
# Yours alone; the plugins themselves are switched on for everyone in Settings > Plugins.
class Settings::MenusController < ApplicationController
  allow_staff
  agent_tool :update_your_menu, on: :update, title: "Arrange the plugins in your menu",
    description: "Which plugins' links show in your nav, and their order (the g 1, g 2… keys follow it). order: every plugin key, in the order you want; shown: the keys to show (the rest are hidden). move: \"key:up\" or \"key:down\" to move one place.",
    params: { order: "string[]", shown: "string[]", move: "string" }

  def update
    keys = Runwell::Plugins.enabled_nav_items.keys.map(&:to_s)
    order = Array(params[:order]).map(&:to_s) & keys
    order += keys - order
    shown = Array(params[:shown]).map(&:to_s) & keys
    moved = move(order, params[:move].to_s)

    Current.user.person.arrange_nav_plugins!(order: order, shown: shown)
    redirect_to settings_account_path(anchor: "menu"), notice: moved ? "Moved #{moved}." : "Your menu is saved."
  end

  private
    # "key:up" or "key:down" swaps that plugin with its neighbour; the plugin's name, if it moved.
    def move(order, move)
      key, direction = move.split(":", 2)
      from = order.index(key) or return
      to = direction == "up" ? from - 1 : from + 1
      return unless to.between?(0, order.size - 1)

      order[from], order[to] = order[to], order[from]
      Runwell::Plugins.enabled_nav_items[key.to_sym]&.first
    end
end
