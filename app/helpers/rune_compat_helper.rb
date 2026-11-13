# The compatibility layer (docs/runeui-migration.md, phase 1): the rune_ui gem's view helpers,
# under the names and signatures the core's views and the plugins call them by, now that the gem
# is out of the Gemfile. Each draws runeui's component (`ui :button`, `ui :badge`, `ui :card`…)
# where runeui has one that does the job, and keeps the class names callers and stylesheets
# rely on (`btn`, `badge`, `card`, `icon-button`…) on it; runwell/compat.css styles those classes
# and dresses the runeui parts drawn here so they sit right beside markup still written by hand.
#
# What stays rune's own markup (styled by compat.css) says so on the helper: pieces runeui has no
# component for (list rows, settings rows, status dots, link tabs) and what its own phase moves
# (the avatar: phases 3 to 5, with the lists and pickers that copy it).
#
# The shell itself is runeui's now (ui :app_shell in the staff layout, phase 2); what's left of
# the gem's shell helpers here are the two names pages and plugins still call: crumbs and
# flash_messages.
#
# This module goes when the plugins have moved to runeui's own API (the plan's phase 10); the
# core stops calling it area by area before then.
module RuneCompatHelper
  # rune's button variants → runeui's.
  BUTTON_VARIANTS = { primary: "default", secondary: "outline", ghost: "ghost", danger: "destructive" }.freeze

  # rune's badge tones → runeui's badge variants. busy is info, pulsing (compat.css).
  BADGE_TONES = { neutral: "secondary", ok: "success", danger: "destructive", attention: "warning", accent: "info", busy: "info", outline: "outline" }.freeze

  # Runwell's statuses (ApplicationHelper::STATUS_TONES) as badge tones, for badge(status).
  STATUS_BADGE_TONES = { "positive" => :ok, "negative" => :danger, "waiting" => :attention, "progress" => :accent, "neutral" => :neutral }.freeze

  # rune's callout tones → runeui's alert variants.
  CALLOUT_TONES = { info: "info", ok: "success", attention: "warning", danger: "destructive" }.freeze

  # ---- Icons ----

  # icon(:search): one of Runwell's 16×16 drawings (Runwell::Icons). label: makes it an image
  # screen readers announce, else it's hidden. Views call icon_tag (ApplicationHelper).
  def icon(name, css: nil, label: nil)
    raise ArgumentError, "no icon #{name.inspect}" unless Runwell::Icons.key?(name)

    tag.svg(Runwell::Icons.fetch(name).html_safe, class: [ "icon", css ], viewBox: "0 0 16 16",
      aria: (label ? { label: label } : { hidden: true }), role: ("img" if label))
  end

  # ---- Buttons: runeui's button (class ui-button, data-variant, data-size) ----

  # The classes for something written by hand (link_to, button_to, form.button, a <summary>), as
  # one string. A class can't carry runeui's data-variant, so these are still rune's btn classes,
  # drawn by compat.css; the helpers below draw runeui's button, dressed to match.
  def button_classes(variant: :secondary, size: :md, extra: nil)
    raise ArgumentError, "unknown button variant #{variant}" unless BUTTON_VARIANTS.key?(variant)

    [ "btn", "btn--#{variant}", ("btn--sm" if size == :sm), extra ].compact.join(" ")
  end

  # A link that looks like a button. icon: before the label; arrow: true, a chevron after it.
  def button_link(label, url, variant: :secondary, size: :md, icon: nil, arrow: false, **options)
    content = safe_join([ (icon(icon) if icon), label, (icon(:chevron) if arrow) ].compact, " ")
    ui :button, href: url_for(url), content: content, **rune_button_options(variant:, size:, **options)
  end

  # A button that sends a request (button_to), with an optional confirmation.
  def action_button(label, url, method: :post, variant: :secondary, size: :md, confirm: nil, params: {}, **options)
    form = { data: { turbo_confirm: confirm }.compact }
    form[:data][:turbo] = false if options.delete(:turbo) == false
    button_to label, url, method:, params:, form:, **rune_button_attributes(variant:, size:, **options)
  end

  # A form's button. It shows it's working while the form is sent (helpers/busy_buttons).
  def submit_button(form, label = nil, variant: :primary, size: :md, **options)
    form.button label, type: "submit", **rune_button_attributes(variant:, size:, **options)
  end

  # A square button with only an icon; label is what screen readers and the tooltip say.
  def icon_button(name, label:, url: nil, **options)
    options = Runeui::Attributes.merge({ class: "icon-button", title: label, aria: { label: label } }, options)
    ui :button, variant: :ghost, size: :icon_sm, href: (url_for(url) if url), type: ("button" unless url), content: icon(name), **options
  end

  def button_row(&buttons)
    tag.div capture(&buttons), class: "button-row"
  end

  # ---- Page ----

  # The panel bar's trail, for a page that sets its own: crumbs("Bots", [bot.name, bot]),
  # strings or [label, path], the last the page you're on. layouts/shared/_panel_bar draws it
  # with ui :breadcrumb (otherwise the trail is parent_page and the page's title).
  def crumbs(*parts)
    @crumbs = parts.compact.map { |part| part.is_a?(Array) ? [ part[0], (url_for(part[1]) if part[1]) ] : part }
    nil
  end

  # The flash, for runeui's toaster (ui_flash_toasts): a notice goes by itself, an alert stays
  # until closed. Each layout renders it once (layouts/shared/_feedback). A message may be a hash
  # for a toast with an action (AnswersInPlace#undo_notice). toast: is accepted and ignored:
  # every message is a toast.
  def flash_messages(toast: true)
    ui_flash_toasts
  end

  # The page's title (in the panel bar, after its trail) and, in the page, what it's for and its
  # actions (the block). subtitle: text, or an array shown as a dotted list.
  def page_header(title, subtitle = nil, trail: [], &actions)
    crumbs(*trail, title)
    subtitle = tag.span(safe_join(subtitle.compact_blank.map { tag.span(it) }), class: "dot-list") if subtitle.is_a?(Array)
    ui :page_header, description: subtitle.presence, actions: (capture(&actions).presence if actions), class: "page-header"
  end

  # A section: runeui's card. actions: buttons beside its title. flush: its content (a list or
  # table) runs to the edges. hint: a line under the title. Other options go on the card.
  def card(title = nil, actions: nil, hint: nil, css: nil, flush: false, **options, &body)
    classes = [ "card", css.presence, ("card--flush" if flush), options.delete(:class) ].compact
    ui :card, title: (tag.h2(title, class: "card__title") if title.present?), description: hint.presence,
      action: (tag.div(actions, class: "button-row") if actions.present?), content: capture(&body), class: classes, **options
  end

  # One row of a list: avatar · title · muted detail · meta. rune's own markup (runeui has rows
  # only inside its menus and lists), styled by compat.css.
  def list_row(url, title:, sub: nil, meta: nil, avatar: nil, id: nil)
    content = safe_join([ avatar, tag.span(title, class: "list-row__title"), tag.span(sub, class: "list-row__sub"),
                          (tag.span(meta, class: "list-row__meta") if meta.present?) ].compact)
    if url
      link_to content, url, class: "list-row", id: id, data: { nav_item: true }
    else
      tag.div content, class: "list-row list-row--static", id: id
    end
  end

  # Nothing to show: runeui's empty. compact: inside a card, without the dashed box (its sm size).
  def empty_state(text, compact: false, &action)
    action = capture(&action) if action
    ui :empty, description: text, action: (tag.div(action, class: "button-row") if action.present?),
      size: (:sm if compact), class: [ "empty", ("empty--compact" if compact) ].compact
  end

  # ---- Forms ----

  # A labelled form field: runeui's field around the input (the block), the label a real <label>
  # for it, the hint its description.
  def field(form, method, label: nil, hint: nil, rich: false, placeholder: nil, &input)
    input_html = rich ? rich_text_field(form, method, placeholder: placeholder) : capture(&input)
    ui :field, description: hint.presence, class: "field",
      content: safe_join([ form.label(method, label, data: { slot: "field-label" }), input_html ])
  end

  # Copies text to the clipboard; says "Copied" for a moment (rune-clipboard, carried into
  # controllers/).
  def copy_button(text, label: "Copy", icon_only: false)
    tag.span(class: "copy", data: { controller: "rune-clipboard", rune_clipboard_text_value: text }) do
      wiring = { rune_clipboard_target: "button", action: "rune-clipboard#copy" }
      if icon_only
        icon_button(:copy, label: label, data: wiring)
      else
        ui :button, content: label, type: "button", **rune_button_options(variant: :secondary, size: :sm, data: wiring)
      end
    end
  end

  # A value people paste elsewhere (an address), with a Copy button.
  def copy_field(value)
    tag.div(class: "copy-field") { tag.code(value, title: value) + copy_button(value) }
  end

  # Settings rows: a heading above a card of rows, each a label (and hint) on the left and its
  # control on the right. rune's own markup (runeui has no settings row), styled by compat.css.
  def settings_group(title, hint: nil, &rows)
    tag.section safe_join([ tag.h2(title, class: "settings-group__title"), (tag.p(hint, class: "settings-group__hint") if hint.present?),
                            tag.div(capture(&rows), class: "settings-group__card") ].compact), class: "settings-group"
  end

  def setting_row(label, hint: nil, for_id: nil, &control)
    label_html = for_id ? label_tag(for_id, label, class: "setting-row__label") : tag.span(label, class: "setting-row__label")
    text = tag.div(safe_join([ label_html, (tag.span(hint, class: "setting-row__hint") if hint.present?) ].compact), class: "setting-row__text")
    tag.div safe_join([ text, tag.div(capture(&control), class: "setting-row__control") ]), class: "setting-row"
  end

  # ---- Menus: runeui's menu ----

  # Secondary actions behind one button: fill it with #menu_link, #menu_button, #menu_label and
  # #menu_divider (or `ui :menu, part: "items", items: […]` for an item that runs a Stimulus
  # action). up: opens above it. trigger_class: the button's look instead of a regular button
  # (label can then be any HTML, like an icon and a name).
  def menu(label = "More", up: false, trigger_class: nil, &items)
    ui :menu, trigger: rune_menu_trigger(label, trigger_class), content: capture(&items), class: [ "menu", ("menu--up" if up) ].compact,
      side: (up ? :top : :bottom), align: (up ? :start : :end)
  end

  # The same, by its older name: runeui's menus all open in the top layer, so rows that scroll
  # or clip need nothing special. side: :bottom or :top; align: :start or :end.
  def popover_menu(label, id: nil, side: :bottom, align: :end, trigger_class: nil, title: nil, &items)
    ui :menu, id: id, trigger: rune_menu_trigger(label, trigger_class, title: title), content: capture(&items), class: "popover-menu",
      side: side, align: align
  end

  def menu_link(label, url, **options)
    data = options.delete(:data) || {}
    ui :menu, part: "items", items: [ { label: label, href: url_for(url), data: data, target: options[:target] } ]
  end

  # An item that sends a request: a link Turbo submits with the method (data-turbo-method).
  # params: go in its address.
  def menu_button(label, url, method: :post, danger: false, confirm: nil, icon: nil, params: {}, checked: nil, data: {})
    href = params.present? ? "#{url_for(url)}#{url_for(url).include?("?") ? "&" : "?"}#{params.to_query}" : url_for(url)
    label = safe_join([ icon(icon), label ]) if icon
    label = safe_join([ label, icon(:check) ]) if checked
    ui :menu, part: "items", items: [ { label: label, href: href, method: method, confirm: confirm, variant: (:destructive if danger), data: data } ]
  end

  def menu_label(text) = ui(:menu, part: "items", items: [ { heading: text } ])
  def menu_divider = ui(:menu, part: "items", items: [ :separator ])

  # ---- Marks ----

  # badge("failed") or badge("pending", "Needs approval"): the status picks the tone
  # (STATUS_BADGE_TONES). badge("Done 6 Nov", tone: :ok): any text, the tone given. A snake_case
  # status shows humanized; other text as it is. runeui's badge.
  def badge(status, label = nil, tone: nil, **options)
    label ||= status.is_a?(Symbol) || status.to_s.match?(/\A[a-z_]+\z/) ? status.to_s.humanize : status.to_s
    tone = (tone || rune_tone_for(status)).to_sym
    ui :badge, content: label, variant: BADGE_TONES.fetch(tone, "secondary"), **Runeui::Attributes.merge({ class: "badge badge--#{tone}" }, options)
  end

  # A dot for a state: :attention (amber), :unread (accent), :failed (red), :busy (spinner).
  # rune's own markup (runeui has no status dot), styled by compat.css.
  def status_dot(state, label: nil)
    tag.span class: "status status--#{state}", title: label, aria: { label: label }, role: ("img" if label)
  end

  # "5 minutes ago" (or "5m ago" with short: true), kept current on the page (rune-local-time,
  # carried into controllers/).
  def time_ago(time, short: false)
    return "—" unless time

    seconds = (Time.current - time).to_i
    text = if !short then "#{time_ago_in_words(time)} ago"
    elsif seconds < 60 then "now"
    elsif seconds < 3600 then "#{seconds / 60}m ago"
    elsif seconds < 86_400 then "#{seconds / 3600}h ago"
    else "#{seconds / 86_400}d ago"
    end
    tag.time text, datetime: time.iso8601, title: time.to_fs(:long),
      data: { controller: "rune-local-time", rune_local_time_datetime_value: time.iso8601, rune_local_time_short_value: short }
  end

  # A person (or anything named) as a round picture, or their initials on a steady colour.
  # size: nil (18px), :md (24px), :lg (28px). title: the tooltip and what screen readers say.
  # rune's own markup, styled by compat.css: every list, card and picker draws people with it
  # (person_tag), and the pickers copy it from a template as they redraw, so it moves to
  # ui :avatar with them (phases 3 to 5).
  def avatar(name, url: nil, size: nil, title: name, **options)
    hue = name.to_s.bytes.sum % 8
    ui :avatar, src: url, name: title, initials: initials(name), size: { md: :sm, lg: :default }.fetch(size&.to_sym, :sm),
      class: [ "avatar", "letter--#{hue}", ("avatar--#{size}" if size), ("avatar--xs" unless size), options.delete(:class) ], **options
  end

  # Nobody: a dashed circle.
  def empty_avatar(title = "Nobody", size: nil)
    tag.span class: [ "avatar", "avatar--empty", ("avatar--#{size}" if size) ], title: title, role: "img", aria: { label: title }
  end

  # Overlapping avatars: avatar_stack { safe_join(people.map { avatar(it.name) }) }
  def avatar_stack(&avatars) = tag.div(capture(&avatars), class: "avatar-stack", role: "group", data: { slot: "avatar-group", size: "sm" })

  def initials(name)
    words = name.to_s.strip.split(/\s+/)
    (words.size > 1 ? words.first(2).map { it[0] } : [ words.first.to_s[0, 2] ]).join.upcase
  end

  # ---- Overlays: runeui's dialog, drawer and alert dialog ----

  # A modal dialog and the button that opens it. trigger: the button's label (any HTML);
  # trigger_class: its look (a regular button by default). The block is the body; give it actions
  # with #dialog_actions. Esc, the × and a click outside close it. size: :lg for a wide one.
  def dialog(title, trigger:, trigger_class: nil, id: nil, size: nil, &body)
    rune_modal(:dialog, id) do |modal_id|
      ui :dialog, id: modal_id, title: title, trigger: rune_modal_trigger(trigger, trigger_class), size: size, content: capture(&body), class: "dialog-wrap"
    end
  end

  # The same, sliding in from the right: runeui's drawer.
  def sheet(title, trigger:, trigger_class: nil, id: nil, &body)
    rune_modal(:sheet, id) do |modal_id|
      ui :drawer, id: modal_id, title: title, trigger: rune_modal_trigger(trigger, trigger_class), content: capture(&body), class: "dialog-wrap"
    end
  end

  # A dialog's or sheet's buttons: Cancel (which closes it), then the block's.
  def dialog_actions(&buttons)
    cancel = ui :button, content: "Cancel", type: "button", **rune_button_options(variant: :ghost, size: :md, data: { runeui_close: @rune_modal_id })
    tag.div safe_join([ cancel, capture(&buttons) ]), class: "dialog__actions"
  end

  # "Delete this?" for any destructive action: runeui's alert dialog, with the trigger, a
  # sentence, and the button that sends it.
  def confirm_dialog(trigger, url, title:, body: nil, button: "Delete", method: :delete, trigger_class: nil)
    opener = tag.button(trigger, type: "button", aria: { haspopup: "dialog" }, **(trigger_class ? { class: trigger_class } : rune_button_attributes(variant: :danger, size: :md)))
    ui :alert_dialog, trigger: opener, title: title, description: body, action: button, variant: :destructive, href: url_for(url), method: method
  end

  # Tabs as links: tabs([["Work", work_path, current: true, count: 3], ["History", history_path]]).
  # Or as buttons that set state: pass a block and write the buttons yourself, with aria-pressed
  # (or aria-selected). pills: true draws them as a segmented strip. rune's own markup, styled by
  # compat.css: runeui's tabs switch panels in place, and these are links to pages; the record
  # pages' tabs move in phase 5.
  def tabs(items = nil, label: "Sections", pills: false, &buttons)
    content = if buttons
      capture(&buttons)
    else
      safe_join(items.map do |text, url, options = {}|
        link_to url, class: "tabs__tab", aria: { current: ("page" if options[:current]) }, data: options[:data] do
          safe_join([ (icon(options[:icon]) if options[:icon]), text, (tag.span(options[:count], class: "count count--quiet") if options[:count]) ].compact)
        end
      end)
    end
    tag.nav content, class: [ "tabs", ("tabs--pills" if pills) ].compact, aria: { label: label }
  end

  # A message that stays on the page (not a flash): runeui's alert. tone :info, :ok, :attention,
  # :danger. (Not `alert`: that's Rails' flash[:alert] helper.)
  def callout(text = nil, tone: :info, title: nil, &body)
    ui :alert, variant: CALLOUT_TONES.fetch(tone.to_sym), title: title, content: (body ? capture(&body) : text),
      role: (tone.to_sym == :danger ? "alert" : "status")
  end

  # A bar for how far along something is (0–100): runeui's progress.
  def progress_bar(percent, label: nil)
    ui :progress, value: percent.to_f.clamp(0, 100).round, size: :sm, class: "progress", aria: { label: label }
  end

  private
    # The status → tone lookup rune_ui kept in RuneUi.badge_tones (Runwell's statuses); a tone's
    # own name passes through, anything else is neutral.
    def rune_tone_for(status)
      tone = STATUS_BADGE_TONES[ApplicationHelper::STATUS_TONES[status.to_s.downcase]] || status.to_s
      BADGE_TONES.key?(tone.to_sym) ? tone.to_sym : :neutral
    end

    # runeui's button as attributes for a tag helper (button_to, form.button): the ui-button
    # class with its data-variant and data-size, and rune's btn classes beside it for the
    # stylesheets and plugins that select on them.
    def rune_button_attributes(variant:, size:, **options)
      raise ArgumentError, "unknown button variant #{variant}" unless BUTTON_VARIANTS.key?(variant)

      Runeui::Attributes.merge({ class: "ui-button #{button_classes(variant:, size:)}",
        data: { variant: BUTTON_VARIANTS.fetch(variant), size: (size == :sm ? "sm" : "default") } }, options)
    end

    # The same as locals for `ui :button`.
    def rune_button_options(variant:, size:, **options)
      raise ArgumentError, "unknown button variant #{variant}" unless BUTTON_VARIANTS.key?(variant)

      Runeui::Attributes.merge({ class: button_classes(variant:, size:) }, options)
        .merge(variant: BUTTON_VARIANTS.fetch(variant), size: (size == :sm ? :sm : nil))
    end

    # A menu's trigger: an outline button with a chevron, or the caller's own look.
    def rune_menu_trigger(label, trigger_class, title: nil)
      if trigger_class
        tag.button(label, type: "button", class: trigger_class, title: title)
      else
        tag.button(safe_join([ label, " ", icon(:chevron, css: "icon--down") ]), type: "button", title: title, **rune_button_attributes(variant: :secondary, size: :md))
      end
    end

    def rune_modal_trigger(trigger, trigger_class)
      tag.button(trigger, type: "button", aria: { haspopup: "dialog" }, **(trigger_class ? { class: trigger_class } : rune_button_attributes(variant: :secondary, size: :md)))
    end

    # Renders a dialog or sheet with an id its Cancel button (dialog_actions) can close it by.
    def rune_modal(kind, id)
      outer = @rune_modal_id
      @rune_modal_id = id || "#{kind}-#{SecureRandom.hex(4)}"
      yield @rune_modal_id
    ensure
      @rune_modal_id = outer
    end
end
