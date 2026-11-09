# Settings > Sidebar (NavLayout): the nav down the left for the whole install, arranged like template
# mode arranges fields: sections in order, each named (or not), holding the core's pages and
# plugins' in any order, and a Hidden tray. The page arranges it by dragging or the keys
# (nav-layout controller) and sends it whole; agents read and set the same.
class Settings::SidebarsController < ApplicationController
  allow_staff
  require_permission :manage_settings
  agent_tool :show_sidebar, on: :show, title: "Show how the sidebar is arranged",
    description: "Its sections in order, each with its label (blank: no heading) and items in order, and the hidden items. An item is a core page (clients, works, tasks, users) or a plugin's (plugin.<key>), with its name."
  agent_tool :arrange_sidebar, on: :update, title: "Arrange the sidebar",
    description: "For everyone on this install. sections: in order, each { label, items } (label blank for no heading; items keys from show_sidebar, in order); hidden: items kept out of the sidebar. Each item once; one left out joins the end of the first section. People can still hide plugins for themselves (Your menu).",
    params: { sidebar: { sections: [ { label: "string", items: "string[]" } ], hidden: "string[]" } }, next_tools: %i[show_sidebar]
  agent_tool :reset_sidebar, on: :destroy, title: "Put the sidebar back as it came"

  def show
    @layout = Setting.current.nav_layout
  end

  def update
    sidebar = params.fetch(:sidebar, {})
    sections = sidebar[:sections]
    sections = sections.to_unsafe_h.sort_by { |index, _| index.to_i }.map(&:last) if sections.respond_to?(:to_unsafe_h)
    sections = Array(sections).map { |section| { label: section[:label] || section["label"], items: Array(section[:items] || section["items"]) } }
    Setting.current.arrange_nav!(sections: sections, hidden: Array(sidebar[:hidden]))
    redirect_to settings_sidebar_path, notice: "The sidebar is arranged for everyone."
  rescue ArgumentError => error
    redirect_to settings_sidebar_path, alert: error.message
  end

  def destroy
    Setting.current.reset_nav!
    redirect_to settings_sidebar_path, notice: "The sidebar is back as it came."
  end
end
