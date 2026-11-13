# How every page looks: Runwell's stylesheets (and plugins'), the install's custom CSS, and
# Settings > Appearance as attributes on <html>.
module AppearanceHelper
  # What the rune_ui gem's sheets styled, carried into Runwell with the compatibility layer
  # (docs/runeui-migration.md, phase 1): the old tokens, bare elements and classes, in the `rune`
  # cascade layer, and the Lexxy editor's skin. Linked first, before runeui's sheets, so rune's
  # layers come before runeui's (a runeui component beats a bare-element rule) and everything
  # below, unlayered, beats both.
  COMPAT_STYLESHEETS = %w[runwell/compat runwell/compat-lexxy].freeze

  # Runwell's own stylesheets, after those (which are in the `rune` layer, so these win):
  # the palette and its settings (_global, appearance, font-face: the theming contract,
  # docs/theming.md), the bridge that points rune's tokens at it (rune-theme), the shell
  # (runwell), the pieces every area shares (runwell/components) and each area's own.
  RUNWELL_STYLESHEETS = %w[_global appearance font-face rune-theme runwell runwell/components runwell/home runwell/tasks runwell/records runwell/settings runwell/public].freeze

  # Herb compiles stylesheet_link_tag into a single <link>, so each list is spelled out.
  # Plugin stylesheets get their own tag.
  def app_stylesheet_tags
    safe_join([
      stylesheet_link_tag(*COMPAT_STYLESHEETS.reject { it == "runwell/compat-lexxy" && !defined?(::Lexxy) }, "data-turbo-track": "reload"),
      # runeui, beside the old classes until the flip (docs/runeui-migration.md): its components'
      # sheets only, with no tokens, page styles or theme switch of its own. Its toaster shows the
      # flash and turbo_stream_flash, and data-turbo-confirm asks in its dialog (both rendered by
      # layouts/shared/_feedback). Then the bridge, which defines runeui's tokens from rune's on
      # runeui's own parts, so Appearance reaches them and nothing of runeui's lands on the page.
      # Runwell's sheets still come last.
      runeui_tags(tokens: false, page: false, theme: false, "data-turbo-track": "reload"),
      stylesheet_link_tag("runeui/bridges/rune_ui", "data-turbo-track": "reload"),
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
  # can both use them.
  def appearance_data
    setting = Setting.current
    { scheme: setting.scheme, radius: setting.radius, font: setting.font, default_theme: setting.theme,
      text_size: Current.user&.text_size.presence || setting.text_size }
  end
end
