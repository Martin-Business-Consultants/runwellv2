# Which plugins' links someone keeps in their nav (Settings > Your account > Your menu): theirs
# alone, beside the install's sidebar (NavLayout, Settings > Sidebar), which says where everything
# sits. `nav_plugins` holds { "hidden" => keys } (and the "order" an earlier release kept, no longer
# read); blank shows every plugin that's on. A plugin switched on later shows until they hide it.
module User::NavPlugins
  extend ActiveSupport::Concern

  def hidden_nav_plugins = Array(nav_plugins.to_h["hidden"]).map(&:to_s)
  def nav_plugin_hidden?(key) = key.to_s.in?(hidden_nav_plugins)

  # Saves which plugins show: every key there is (order), and those of them to show.
  def arrange_nav_plugins!(order:, shown:)
    order = Array(order).map(&:to_s).uniq
    update!(nav_plugins: { "hidden" => order - Array(shown).map(&:to_s) })
  end
end
