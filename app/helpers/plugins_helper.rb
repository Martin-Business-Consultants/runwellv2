# What plugins add to the core's pages (Runwell::Plugins): their slots and their nav links.
module PluginsHelper
  # What plugins registered for a slot in this view (Runwell::Plugins).
  def plugin_slots(name, **locals)
    safe_join(Runwell::Plugins.enabled_slots(name).values.map { render(it, **locals) })
  end

  # The same, leaving out a plugin that had nothing to show (its partial drew only whitespace,
  # comments or empty wrappers), so a box around the slot is drawn only when something's in it.
  def visible_plugin_slots(name, **locals)
    safe_join(Runwell::Plugins.enabled_slots(name).values.map { render(it, **locals) }.select { visible_markup?(it) })
  end

  def visible_markup?(html)
    strip_tags(html.to_s).strip.present? || html.to_s.match?(/<(img|svg|video|iframe|canvas|input|button|select|textarea)\b/i)
  end

  # The left nav as the install arranges it (NavLayout, Settings > Sidebar) for the signed-in
  # person: [[section label, [[label, url, icon, keys], …]], …], leaving out plugins they hide (Your
  # menu) and links whose path is nil, then sections with nothing left. Plugins' pages are numbered
  # g 1, g 2… in the order they show.
  def nav_sections
    @nav_sections ||= begin
      person = Current.user&.person
      plugins = Runwell::Plugins.enabled_nav_items
      number = 0
      Setting.current.nav_layout.sections.filter_map do |section|
        links = section["items"].filter_map do |item|
          key = NavLayout.plugin_key(item)
          next core_nav_link(item) unless key
          next if person&.nav_plugin_hidden?(key)

          label, path, icon = plugins[key]
          url = path && instance_exec(&path)
          next unless url

          [ label, url, icon || "grid", "g #{number += 1}" ]
        end
        [ section["label"], links ] if links.any?
      end
    end
  end

  # The plugins' pages in the nav, with their go-to keys, for the shortcut sheet.
  def nav_plugin_shortcuts = nav_sections.flat_map(&:last).select { it[3]&.match?(/\Ag \d+\z/) }

  # A core section in the nav: [label, path, icon, keys].
  def core_nav_link(item)
    case item
    when "clients" then [ term(:client, count: 2), clients_path, "everyone", "g c" ]
    when "works" then [ term(:work, count: 2), works_path, "clipboard", "g w" ]
    when "tasks" then [ term(:task, count: 2), tasks_path, "board", "g t" ]
    when "users" then [ "Users", users_path, "person", "g u" ]
    end
  end

  # Every switched-on plugin's page, in the install's sidebar order (hidden ones last), for Your
  # menu: [[key, label, icon], …].
  def nav_menu_items
    layout = Setting.current.nav_layout
    items = layout.sections.flat_map { it["items"] } + layout.hidden
    plugins = Runwell::Plugins.enabled_nav_items
    items.filter_map { NavLayout.plugin_key(it) }.select { plugins.key?(it) }.map { |key| [ key.to_s, plugins[key][0], plugins[key][2] || "grid" ] }
  end

  # An item's name and icon for arranging the sidebar: a core section or a plugin's page.
  def nav_item_name(item)
    key = NavLayout.plugin_key(item)
    return core_nav_link(item)&.values_at(0, 2) unless key

    label, _path, icon = Runwell::Plugins.enabled_nav_items[key]
    [ label || key.to_s.humanize, icon || "grid" ]
  end

  # A plugin's path lambda may return nil to leave its link out (nothing to show this client).
  def plugin_portal_nav_links(**options)
    safe_join(Runwell::Plugins.enabled_portal_nav_items.values.filter_map do |label, path, replaces|
      next if replaces

      url = instance_exec(&path)
      link_to(label, url, **options, aria: { current: (url && request.path.start_with?(url.split("?").first)) ? "page" : "false" }) if url
    end)
  end

  # The portal's link to one of its own pages (page: :documents), or the switched-on plugin's link
  # standing in for it (Runwell::Plugins.portal_nav replaces:).
  def portal_page_link(page, label, path, **options)
    if (replacement = Runwell::Plugins.portal_replacement(page)) && (url = instance_exec(&replacement.last))
      label, path = replacement.first, url
    end
    link_to label, path, **options, aria: { current: request.path.start_with?(path.split("?").first) ? "page" : "false" }
  end
end
