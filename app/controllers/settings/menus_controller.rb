# Settings > Your account > Your menu: which plugins' links show in your nav. Yours alone; where
# they sit (sections, order) is the install's, in Settings > Sidebar, and the plugins themselves are
# switched on for everyone in Settings > Plugins.
class Settings::MenusController < ApplicationController
  allow_staff
  agent_tool :update_your_menu, on: :update, title: "Choose which plugins show in your menu",
    description: "Which plugins' links show in your nav (the g 1, g 2… keys follow the ones shown). shown: the plugin keys to show; the rest are hidden for you. Where they sit is the install's sidebar (arrange_sidebar).",
    params: { shown: "string[]" }

  def update
    keys = Runwell::Plugins.enabled_nav_items.keys.map(&:to_s)
    shown = Array(params[:shown]).map(&:to_s) & keys

    Current.user.person.arrange_nav_plugins!(order: keys, shown: shown)
    redirect_to settings_account_path(anchor: "menu"), notice: "Your menu is saved."
  end
end
