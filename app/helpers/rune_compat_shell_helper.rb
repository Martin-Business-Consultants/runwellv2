# The compatibility layer's shell (docs/runeui-migration.md, phase 1; RuneCompatHelper has the
# components): the rune_ui gem's frame around every staff page, its stylesheet tag, the panel
# bar's trail and the flash, under the gem's names. These keep rune's own markup, styled by
# runwell/compat.css and worked by the rune-* controllers carried into app/javascript/controllers
# (rune-sidebar, rune-flash): the shell, the breadcrumb and the toasts are the plan's phase 2
# (`ui :app_shell`, `ui :breadcrumb`, `ui :toaster`), which replaces this module's callers and
# then the module.
module RuneCompatShellHelper
  # What the gem's sheets styled, now Runwell's: runwell/compat.css (in the `rune` layer) and the
  # Lexxy editor's skin. Linked first, before runeui's sheets, so rune's layers stay under
  # runeui's (AppearanceHelper#app_stylesheet_tags).
  def rune_ui_stylesheet_tags(lexxy: defined?(::Lexxy), fonts: false)
    stylesheet_link_tag(*AppearanceHelper::COMPAT_STYLESHEETS.reject { it == "runwell/compat-lexxy" && !lexxy }, "data-turbo-track": "reload")
  end

  # data-theme for <html>: "light" or "dark" pins it; nil or "system" follows the device.
  def theme_data(theme)
    theme.present? && theme.to_s != "system" ? { theme: theme } : {}
  end

  # sidebar: its HTML (a nav.sidebar). main: the page. storage_key: where the collapsed state is
  # remembered. bar: the panel bar's content after the toggle (instead of the crumbs and
  # :context); toggle: its own toggle button; flash: its own flash markup; attributes: merged
  # onto the shell (id, data: { controller: "…" } adds controllers); main_attributes: onto <main>;
  # main_class: an extra class there; after: HTML after the shell. (shortcuts: is accepted and
  # ignored: rune-shortcuts went with the gem, Runwell's keys are the keyboard controller.)
  def app_shell(sidebar:, main:, storage_key: "rune.sidebar", bar: nil, toggle: nil, flash: nil, shortcuts: false,
                attributes: {}, main_attributes: {}, main_class: nil, after: nil)
    attributes = attributes.deep_dup
    data = attributes.delete(:data) || {}
    controllers = [ "rune-sidebar", data.delete(:controller) ].compact.join(" ")
    app_attributes = attributes.merge(data: data.merge(controller: controllers, rune_sidebar_key_value: storage_key).compact)

    bar ||= safe_join([
      tag.nav(content_for?(:crumbs) ? content_for(:crumbs) : tag.span(content_for(:title), class: "crumbs__current"), class: "crumbs", aria: { label: "You are here" }),
      tag.div(content_for(:context), class: "panel-bar__context")
    ])
    panel = tag.div(class: "panel") do
      safe_join([
        tag.header(safe_join([ toggle || sidebar_toggle(class: "panel-bar__toggle"), bar ]), class: "panel-bar"),
        tag.main(safe_join([ flash || flash_messages, main ]), **main_attributes, class: [ "main", main_class ].compact)
      ])
    end
    shell = tag.div(safe_join([ sidebar, tag.div(class: "sidebar-scrim", data: { action: "click->rune-sidebar#close" }), panel ]),
      **app_attributes, class: "app")
    safe_join([ shell, after ].compact)
  end

  # The bare frame for signed-out pages (sign in): a narrow column.
  def narrow_shell(main:)
    tag.main(safe_join([ flash_messages, main ]), class: "main main--narrow")
  end

  def sidebar_toggle(label: "Show the sidebar", **options)
    icon_button(:sidebar, label: label, data: { action: "rune-sidebar#toggle" }, **options)
  end

  def sidebar_section(label) = tag.div(label, class: "sidebar__section")

  # The trail at the top of the panel: crumbs("Bots", [bot.name, bot]): strings or
  # [label, path]. The last is the current page.
  def crumbs(*parts)
    parts = parts.compact
    content_for :crumbs do
      safe_join(parts.each_with_index.map do |part, index|
        label, path = Array(part)
        node = index == parts.size - 1 ? tag.span(label, class: "crumbs__current") : (path ? link_to(label, path) : tag.span(label))
        index.zero? ? node : safe_join([ tag.span("/", class: "crumbs__sep"), node ])
      end)
    end
  end

  # Notices and alerts as dismissible messages. toast: true floats them in the bottom right, out
  # of the page's flow (lift them with --toast-bottom). A notice goes by itself after six
  # seconds; an alert stays.
  #
  # A message may carry an action, a button beside its text (Undo): give the flash a hash,
  #   flash.now[:notice] = { text: "Removed.", action: { label: "Undo", url: undo_path, method: :delete }, timeout: 8000 }
  # (string keys work too, so it survives a redirect). The action is a button_to; data: goes on
  # its form. timeout: how long it stays, in ms (0 stays until closed).
  def flash_messages(toast: false)
    messages = { notice: flash[:notice], alert: flash[:alert] }.compact_blank
    return if messages.empty?

    tag.div(class: [ "flashes", ("flashes--toast" if toast) ].compact.join(" ")) do
      safe_join(messages.map do |kind, message|
        text, action, timeout = flash_parts(kind, message)
        tag.div(class: "flash flash--#{kind}", role: (kind == :alert ? "alert" : "status"),
                data: { controller: "rune-flash", rune_flash_timeout_value: timeout }) do
          safe_join([ tag.span(text, class: "flash__text"), (flash_action(action) if action),
                      icon_button(:close, label: "Dismiss", class: "flash__close", data: { action: "rune-flash#close" }) ].compact)
        end
      end)
    end
  end

  private
    def flash_parts(kind, message)
      default = kind == :notice ? 6000 : 0
      return [ message, nil, default ] unless message.is_a?(Hash)

      message = message.with_indifferent_access
      [ message[:text], message[:action], message[:timeout] || default ]
    end

    def flash_action(action)
      action = action.with_indifferent_access
      button_to action[:label], action[:url], method: action[:method] || :post, params: action[:params] || {},
        class: "btn btn--secondary btn--sm flash__action", form_class: "flash__action-form", form: { data: action[:data] || {} }
    end
end
