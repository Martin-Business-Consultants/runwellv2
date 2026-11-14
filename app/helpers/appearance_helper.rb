# How every page looks: runeui, Runwell's stylesheets (and plugins'), the install's custom CSS,
# and Settings > Appearance as attributes on <html>.
module AppearanceHelper
  # Runwell's theme (appearance.css): runeui's tokens as Settings > Appearance sets them, in a
  # layer over runeui's defaults. Linked first, since its @layer statement is the page's order.
  # Then the compatibility layer (runwell/compat.css): the old token names, derived from runeui's,
  # and rune_ui's classes, for plugins until 7.0 (docs/plugin-contract.md).
  THEME_STYLESHEETS = %w[appearance runwell/compat].freeze

  # Runwell's own stylesheets, after runeui's (unlayered, so these win over every layer): the
  # Inter font, the shell (runwell), the pieces every area shares (runwell/components) and each
  # area's own.
  RUNWELL_STYLESHEETS = %w[font-face runwell runwell/components runwell/trays runwell/tasks runwell/records runwell/settings runwell/public].freeze

  # Herb compiles stylesheet_link_tag into a single <link>, so each list is spelled out.
  # runeui comes as an app's does: its tokens on :root, its page base, its components, Lexxy and
  # runeui's skin for it, and light and dark (the theme script in runeui_tags sets .dark on <html>
  # before the first paint, from the person's choice or data-default-theme). Its toaster shows the
  # flash and turbo_stream_flash, and data-turbo-confirm asks in its dialog (both rendered by
  # layouts/shared/_feedback). Plugin stylesheets get their own tag, last but for custom CSS.
  def app_stylesheet_tags
    safe_join([
      stylesheet_link_tag(*THEME_STYLESHEETS, "data-turbo-track": "reload"),
      runeui_tags(lexxy: defined?(::Lexxy).present?, "data-turbo-track": "reload"),
      stylesheet_link_tag(*RUNWELL_STYLESHEETS, "data-turbo-track": "reload"),
      (stylesheet_link_tag(*Runwell::Plugins.enabled_stylesheets, "data-turbo-track": "reload") if Runwell::Plugins.enabled_stylesheets.any?)
    ].compact, "\n")
  end

  # Custom CSS (Settings > Appearance) on this page: everywhere but the portal always, the portal
  # when the owner says so, and nowhere with ?theme=off.
  def custom_theme?
    setting = Setting.current
    return false if setting.custom_css.blank? || params[:theme] == "off"

    setting.custom_css_everywhere? || !request.path.start_with?("/portal")
  end

  # Settings > Appearance, as attributes on <html> so CSS (appearance.css) and a live preview
  # can both use them. data-default-theme is what runeui's theme script falls back to when the
  # person hasn't chosen light or dark themselves.
  def appearance_data
    setting = Setting.current
    { scheme: setting.scheme, radius: setting.radius, font: setting.font, default_theme: setting.theme,
      text_size: Current.user&.text_size.presence || setting.text_size }
  end
end
