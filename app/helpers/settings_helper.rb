module SettingsHelper
  # A link in the Settings sidebar (settings/_nav), marked when it's the page on screen.
  def settings_nav_link(label, path, current:, icon: nil)
    link_to path, class: class_names("settings-nav__link", "settings-nav__link--nested": icon.nil?), aria: { current: ("page" if current) } do
      safe_join([ (icon_tag(icon) if icon), tag.span(label) ].compact)
    end
  end

  # The plugins nested under Plugins in the sidebar: each switched-on plugin with a settings
  # page, and the plugin on screen when it has only a details page. [key, label, url] each.
  def settings_nav_plugins(current)
    pages = Runwell::Plugins.enabled_settings_pages.filter_map do |key, (label, path)|
      url = instance_exec(&path)
      [ key, label, url ] if url
    end

    manifest = Runwell::Plugins.manifests[current.to_s.to_sym]
    pages << [ manifest.key, manifest.name, settings_plugin_path(manifest.key) ] if manifest && pages.none? { it.first == manifest.key }
    pages
  end
end
