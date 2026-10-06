module SectionNavHelper
  # A sidebar of a section's own pages beside the page, the way Settings has one (the application
  # layout places it): for a plugin with several pages. Each of its pages calls it once, usually
  # through a partial, with headings and links inside:
  #
  #   <% section_nav "Accounts" do %>
  #     <%= section_nav_heading "Your day" %>
  #     <%= section_nav_link "Today", today_path, icon: "home", current: current == :today %>
  #   <% end %>
  def section_nav(label, &block)
    content_for :settings_nav, tag.nav(capture(&block), class: "settings-nav", aria: { label: label })
    nil
  end

  # A small heading over a group of links. Hidden when the sidebar runs across the top.
  def section_nav_heading(text) = tag.p(text, class: "settings-nav__heading")

  # A link in the sidebar, marked when it's the page on screen. Without an icon it's indented, as
  # a page nested under the link above it.
  def section_nav_link(label, path, current: current_page?(path), icon: nil) = settings_nav_link(label, path, current: current, icon: icon)
end
