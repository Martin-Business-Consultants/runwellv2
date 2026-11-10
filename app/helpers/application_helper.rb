module ApplicationHelper
  def page_title_tag
    tag.title [ @page_title, "Runwell" ].compact.join(" | ")
  end

  # Runwell's icons are rune_ui's (config/initializers/rune_ui.rb registers them): an inline SVG,
  # hidden from screen readers. A name nobody registered (a plugin's) draws a dot, not an error.
  def icon_tag(name, **options)
    name = RuneUi.icons.key?(name.to_s.to_sym) ? name : "dot"
    icon(name, css: class_names("icon--#{name}", options.delete(:class)).presence)
  end

  STATUS_TONES = {
    "positive" => %w[done approved active promoted can\ approve on\ track],
    "negative" => %w[overdue blocked missed stopped changes\ requested behind],
    "waiting" => %w[sent open awaiting\ decision awaiting draft planned waiting],
    "progress" => %w[in\ progress],
    "neutral" => %w[closed superseded dormant former dropped dismissed declined not\ started]
  }.flat_map { |tone, labels| labels.map { [ it, tone ] } }.to_h.freeze

  def status_tone(label, highlight: false)
    STATUS_TONES.fetch(label.to_s.downcase) { highlight ? "progress" : "neutral" }
  end

  # A status label tinted by what it means (a rune_ui badge in its tone).
  def status_tag(label, highlight: false) = ui_status_badge(label, highlight: highlight)

  def money(cents) = Money.format(cents)

  # This install's word for a core thing (Settings > Names), e.g. term(:work, count: 2).
  def term(key, count: 1) = Setting.current.term(key, count: count)
  def label_term(label, count: 1) = Setting.current.label_name(label, count: count)

  # The work types to pick from, in the install's order: those switched on, plus `current` (a
  # piece of work keeps its type when it's switched off).
  def label_options(current = nil)
    WorkType.cached.select { !it.archived? || it.key == current.to_s }.map { [ it.name_one, it.key ] }
  end

  # The page one level up (a record's list, a task's work). Not a button: it's a
  # <link rel="up"> in the head (layouts/shared/_head), and Esc goes there (keyboard_controller).
  def parent_page(label, url)
    @breadcrumb_parent = [ label, url_for(url) ]
    content_for :parent_page, tag.link(rel: "up", href: url_for(url), title: label)
    nil
  end

  # The inset header's breadcrumb (layouts/shared/_inset_header): the page's parent, when it
  # named one (parent_page), then the page itself.
  def breadcrumb_items
    [ @breadcrumb_parent, ([ @page_title, nil ] if @page_title.present?) ].compact
  end
end
