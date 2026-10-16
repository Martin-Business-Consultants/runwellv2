# Which plugins' links someone keeps in their nav, and in what order (Settings > Your account): their
# own, beside the install's choice of plugins that are on. `nav_plugins` holds { "order" => keys,
# "hidden" => keys }; blank is every plugin that's on, in the order they registered. A plugin
# switched on later shows, at the end, until they move or hide it.
module User::NavPlugins
  extend ActiveSupport::Concern

  # The plugins' nav items ({ key => item }) as this person arranges them: hidden ones out, their
  # order first, the rest after in registered order.
  def arrange_nav_items(items)
    order = nav_plugin_order & items.keys.map(&:to_s)
    keys = order + (items.keys.map(&:to_s) - order)
    keys.reject { it.in?(hidden_nav_plugins) }.to_h { [ it.to_sym, items[it.to_sym] ] }
  end

  def nav_plugin_order = Array(nav_plugins.to_h["order"]).map(&:to_s)
  def hidden_nav_plugins = Array(nav_plugins.to_h["hidden"]).map(&:to_s)
  def nav_plugin_hidden?(key) = key.to_s.in?(hidden_nav_plugins)

  # Every plugin item ({ key => item }) in this person's order, hidden ones included: for arranging.
  def ordered_nav_items(items)
    order = nav_plugin_order & items.keys.map(&:to_s)
    (order + (items.keys.map(&:to_s) - order)).to_h { [ it.to_sym, items[it.to_sym] ] }
  end

  # Saves a new arrangement: keys in order, and which of them show.
  def arrange_nav_plugins!(order:, shown:)
    order = Array(order).map(&:to_s).uniq
    update!(nav_plugins: { "order" => order, "hidden" => order - Array(shown).map(&:to_s) })
  end
end
