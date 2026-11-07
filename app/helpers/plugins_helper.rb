# What plugins add to the core's pages (Runwell::Plugins): their slots and their nav links.
module PluginsHelper
  # What plugins registered for a slot in this view (Runwell::Plugins).
  def plugin_slots(name, **locals)
    safe_join(Runwell::Plugins.enabled_slots(name).values.map { render(it, **locals) })
  end

  # A plugin's path lambda may return nil to leave its link out (someone without the permission).
  def plugin_nav_links(**options)
    safe_join(Runwell::Plugins.enabled_nav_items.values.each_with_index.filter_map do |(label, path), index|
      url = instance_exec(&path)
      nav_link_to(label, url, keys: "g #{index + 1}", **options) if url
    end)
  end

  # The same links for the left nav, one list item each, under the core's sections.
  # The plugins' nav items that are on, as the signed-in person arranges them (Settings > Your
  # account: their order, without the ones they hide).
  def nav_plugin_items
    items = Runwell::Plugins.enabled_nav_items
    (person = Current.user&.person) ? person.arrange_nav_items(items) : items
  end

  def plugin_sidenav_links
    safe_join(nav_plugin_items.values.each_with_index.filter_map do |(label, path, icon), index|
      url = instance_exec(&path)
      sidenav_link_to(label, url, icon: icon || "grid", keys: "g #{index + 1}") if url
    end)
  end

  # A plugin's path lambda may return nil to leave its link out (nothing to show this client).
  def plugin_portal_nav_links(**options)
    safe_join(Runwell::Plugins.enabled_portal_nav_items.values.filter_map do |label, path|
      url = instance_exec(&path)
      link_to(label, url, **options) if url
    end)
  end
end
