module ApplicationHelper
  def page_title_tag
    tag.title [ @page_title, "Runwell" ].compact.join(" | ")
  end

  # Herb compiles stylesheet_link_tag into a single <link>, which skips Propshaft's :app expansion.
  # Plugin stylesheets get their own tag: Propshaft's :app expansion drops other names.
  def app_stylesheet_tags
    safe_join([
      stylesheet_link_tag(:app, "data-turbo-track": "reload"),
      (stylesheet_link_tag(*Runwell::Plugins.enabled_stylesheets, "data-turbo-track": "reload") if Runwell::Plugins.enabled_stylesheets.any?)
    ].compact, "\n")
  end

  def icon_tag(name, **options)
    tag.span class: class_names("icon icon--#{name}", options.delete(:class)), "aria-hidden": true, **options
  end

  STATUS_TONES = {
    "positive" => %w[done approved active promoted can\ approve],
    "negative" => %w[overdue blocked missed stopped changes\ requested],
    "waiting" => %w[sent open awaiting\ decision awaiting draft planned],
    "progress" => %w[in\ progress],
    "neutral" => %w[closed superseded dormant former dropped dismissed not\ started]
  }.flat_map { |tone, labels| labels.map { [ it, tone ] } }.to_h.freeze

  def status_tone(label, highlight: false)
    STATUS_TONES.fetch(label.to_s.downcase) { highlight ? "progress" : "neutral" }
  end

  # A status label tinted by what it means, in Fizzy's palette.
  def status_tag(label, highlight: false)
    tag.span label, class: "status-tag status-tag--#{status_tone(label, highlight: highlight)} txt-nowrap"
  end

  def money(cents) = Money.format(cents)

  # Settings > Appearance, as attributes on <html> so CSS (appearance.css) and a live preview
  # can both use them.
  def appearance_data
    setting = Setting.current
    { scheme: setting.scheme, radius: setting.radius, font: setting.font, default_theme: setting.theme,
      text_size: Current.user&.text_size.presence || setting.text_size }
  end

  # This install's word for a core thing (Settings > Names), e.g. term(:engagement, count: 2).
  def term(key, count: 1) = Setting.current.term(key, count: count)
  def label_term(label, count: 1) = Setting.current.label_name(label, count: count)

  def label_options(current = nil)
    labels = Setting.current.enabled_labels | Array(current).compact
    Engagement::LABELS.select { labels.include?(it) }.map { [ label_term(it), it ] }
  end

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
  def plugin_sidenav_links
    safe_join(Runwell::Plugins.enabled_nav_items.values.each_with_index.filter_map do |(label, path), index|
      url = instance_exec(&path)
      tag.li(sidenav_link_to(label, url, icon: "grid", keys: "g #{index + 1}")) if url
    end)
  end

  # A plugin's path lambda may return nil to leave its link out (nothing to show this client).
  def plugin_portal_nav_links(**options)
    safe_join(Runwell::Plugins.enabled_portal_nav_items.values.filter_map do |label, path|
      url = instance_exec(&path)
      link_to(label, url, **options) if url
    end)
  end

  # A top nav link, marked as the current page anywhere in its section (/clients, /clients/9…).
  # keys: the go-to chord for the keyboard controller ("g c"), shown in the link's title.
  def nav_link_to(label, path, keys: nil, **options)
    current = request.path == path || request.path.start_with?(path.chomp("/") + "/")
    options = options.merge(title: "#{label} (#{keys})", data: (options[:data] || {}).merge(keys: keys)) if keys
    link_to label, path, **options, aria: { current: ("page" if current) }
  end

  # A section in the left nav: its icon and name, marked current like nav_link_to.
  def sidenav_link_to(label, path, icon:, keys: nil, current: nil)
    current = request.path == path || request.path.start_with?(path.chomp("/") + "/") if current.nil?
    link_to path, class: "sidenav__link", title: (keys ? "#{label} (#{keys})" : label), data: { keys: keys }.compact, aria: { current: ("page" if current) } do
      icon_tag(icon) + tag.span(label, class: "sidenav__label")
    end
  end

  # A Lexxy editor writing HTML straight into a text column. Staff editors carry Fizzy's @
  # prompt and take dropped or pasted files (Active Storage direct uploads); client-facing
  # editors are text only.
  # A money input. The column is integer cents (method, e.g. :price_cents); people see and type
  # dollars, and the money controller keeps the submitted cents in step. value: cents, for a
  # form with no model.
  def money_field(form, method, value: nil, **options)
    money_field_tag(form.field_name(method), value.nil? ? form.object.try(method) : value, id: form.field_id(method), **options)
  end

  # The same, by name, for a field with no form method (custom fields).
  def money_field_tag(name, cents, **options)
    tag.span(class: "money-field", data: { controller: "money" }) do
      safe_join([
        text_field_tag(nil, cents.to_i.zero? ? nil : Money.format(cents).delete_prefix("$"), **options,
          inputmode: "decimal", autocomplete: "off", data: { money_target: "display", action: "input->money#update blur->money#format" }),
        hidden_field_tag(name, cents.nil? ? "" : cents.to_i, id: nil, data: { money_target: "cents" })
      ])
    end
  end

  # A key, token or secret: the saved value (stored encrypted), masked until the eye is clicked.
  # Submitting it unchanged keeps it. A helper, not a partial, so it works inside form_with.
  def secret_field(form, method, placeholder: nil, **options)
    tag.span class: "secret-field", data: { controller: "reveal" } do
      safe_join([
        form.password_field(method, value: form.object.try(method), class: "input full-width", autocomplete: "off",
          spellcheck: false, placeholder: placeholder, data: { reveal_target: "input", "1p-ignore": true }, **options),
        tag.button(type: "button", class: "btn btn--circle btn--plain secret-field__eye", title: "Show", aria: { pressed: false, label: nil },
          data: { reveal_target: "button", action: "reveal#toggle" }) do
          safe_join([ icon_tag("eye", class: "secret-field__show"), icon_tag("eye-off", class: "secret-field__hide"),
            tag.span("Show or hide", class: "for-screen-reader") ])
        end
      ])
    end
  end

  def rich_text_field(form, method, placeholder: nil, staff: false)
    rich_text_field_tag(form.field_name(method), form.object.try(method), id: form.field_id(method), placeholder: placeholder, staff: staff)
  end

  def rich_text_field_tag(name, value, id:, placeholder: nil, staff: false)
    options = { name: name, id: id, value: editor_content(value), placeholder: placeholder, class: "lexxy-content" }
    if staff
      options[:data] = { direct_upload_url: rails_direct_uploads_url, blob_url_template: rails_service_blob_url(":signed_id", ":filename") }
    else
      options[:attachments] = "false"
    end
    content_tag("lexxy-editor", options) { global_mentions_prompt if staff }
  end

  def global_mentions_prompt
    content_tag "lexxy-prompt", "", trigger: "@", src: prompts_users_path, name: "mention"
  end

  # A snippet to read or copy (a command, a request), coloured by Lexxy's highlighter the way
  # code blocks in rich text are. language is a Prism name: bash, json, ruby, javascript.
  def code_block(code, language: "bash", **options)
    tag.pre code, **options, class: class_names("code-block", options[:class]), data: { language: language }
  end

  # Sanitized HTML from a rich text field, with mentions rendered. Older values are plain
  # text, so they keep their line breaks.
  def rich_text(html)
    return if html.blank?

    html = simple_format(html) unless html.include?("<")
    # Always as HTML: during ReActionView's slots request Action Text's own templates would
    # otherwise render in the slots format and come back as data, not markup.
    formats = lookup_context.formats
    lookup_context.formats = [ :html ]
    tag.div render_action_text_content(ActionText::Content.new(html)), class: "lexxy-content"
  ensure
    lookup_context.formats = formats if formats
  end

  # "Back" with Esc; where it goes is in the title. (No aria-label: Fizzy styles a .btn with
  # one and an icon as an icon-only circle.)
  # Every date field: a native <input type="date"> with the date-field controller (click opens
  # the picker; t, +, - and Delete from the keyboard). With a form builder, or as a tag.
  DATE_FIELD_DATA = { controller: "date-field", action: "click->date-field#open keydown->date-field#shortcut" }.freeze

  def date_input(form, method, **options)
    form.date_field(method, **date_input_options(options))
  end

  def date_input_tag(name, value = nil, **options)
    date_field_tag(name, value, **date_input_options(options))
  end

  def date_input_options(options)
    options.merge(data: DATE_FIELD_DATA.merge(options[:data] || {}) { |key, ours, theirs| key == :action ? "#{ours} #{theirs}" : theirs })
  end

  # The page one level up (a record's list, a todo's engagement). Not a button: it's a
  # <link rel="up"> in the head (layouts/shared/_head), and Esc goes there (keyboard_controller).
  def parent_page(label, url)
    content_for :parent_page, tag.link(rel: "up", href: url_for(url), title: label)
    nil
  end

  private
    # Lexxy needs each attachment's rendered content in the editor value, as its own
    # Action Text tag helper does for rich text records.
    def editor_content(html)
      return html unless html.to_s.include?(ActionText::Attachment.tag_name)

      ActionText::Fragment.wrap(html).replace(ActionText::Attachment.tag_name) do |node|
        if node["url"].blank?
          attachment = ActionText::Attachment.from_node(node)
          node["content"] = render_action_text_attachment(attachment).to_json
          node["content-type"] ||= attachment.content_type
        end
        node
      end.to_html
    end
end
