# Template mode: where a kind of record's fields show on its pages (new, edit and show alike), as
# an install's owners arrange them: in the working column (main), the sidebar (aside), or not at
# all (hidden), in order. Placement, order and visibility only: nothing here changes what is
# stored, what's required or what an agent can set, and a hidden field still shows wherever else
# the record does (the side panel, tables, the portal). One layout per kind per install
# (Setting#layouts), kept as the order of field keys under its kind; stored per kind so a per-label
# variant ("work:service") could come later.
#
# Field keys are a contract (docs/plugin-contract.md): a field a release adds joins its default
# column, one it removes is dropped, and custom fields are "custom.<key>" (they start at the end
# of the sidebar on clients and work, of the working column elsewhere). Required fields can't be hidden: saving the record would fail.
class RecordLayout
  ZONES = %w[main aside hidden].freeze

  # Each kind's fields as the core arranges them, and those that can't be hidden.
  DEFAULTS = {
    "client" => { main: %w[name], aside: %w[status time_zone internal], required: %w[name] },
    "work" => { main: %w[title description], aside: %w[client label shape cadence], required: %w[title client] },
    "task" => { main: %w[title description], aside: %w[status due repeat lead others home requested_by source client_visible], required: %w[title source] },
    "user" => { main: %w[name email_address role], aside: [], required: %w[name email_address role] },
    "contact" => { main: %w[name title email phone], aside: %w[portal_access can_approve], required: %w[name] },
    # The client portal's page for a piece of work: its cards, arranged by an owner viewing the
    # portal as a client (View as). Any can be hidden.
    "portal_work" => { main: %w[overview sections tasks], aside: %w[details documents plugins], required: [] }
  }.freeze
  KINDS = DEFAULTS.keys.freeze
  MODELS = { "client" => "Client", "work" => "Work", "task" => "Task", "user" => "User", "contact" => "Contact", "portal_work" => nil }.freeze
  # A kind whose pages have no sidebar to arrange into (a person's page).
  SINGLE_COLUMN = %w[user].freeze

  # Card headings an install may rename (and the line under each), by slot: a record's form card and
  # its sidebar card; the portal's cards.
  PORTAL_CARDS = %w[overview sections tasks details documents].freeze
  TEXT_SLOTS = Hash.new(%w[main.title main.hint aside.title]).merge(
    "portal_work" => PORTAL_CARDS.flat_map { [ "#{it}.title", "#{it}.hint" ] }
  ).freeze
  TEXT_LIMIT = 120

  attr_reader :kind, :main, :aside, :hidden

  def self.for(kind, setting: Setting.current)
    new(kind, setting.layouts.to_h[kind.to_s])
  end

  def initialize(kind, saved = nil)
    raise ArgumentError, "Unknown layout: #{kind}" unless DEFAULTS.key?(kind.to_s)

    @kind = kind.to_s
    @main, @aside, @hidden = arrange(saved || {})
    @text = clean_text((saved || {}).to_h.stringify_keys["text"])
  end

  # A card's heading or the line under it as the install renamed it, else the default.
  def text(slot, default = nil) = @text.fetch(slot.to_s, default)
  def renamed = @text

  def keys = main + aside + hidden
  def zones = single_column? ? %w[main hidden] : ZONES
  def required?(key) = DEFAULTS[kind][:required].include?(key)
  def shown?(key) = !hidden.include?(key)
  def custom_field(key) = custom_fields.find { "custom.#{it.key}" == key }
  def custom?(key) = key.start_with?("custom.")

  # The arrangement as stored: only known keys, each once, required ones never hidden. A key the
  # page didn't send keeps its column (a page that shows only some fields can still save).
  # Renamed headings: only the kind's slots, plain text, trimmed; a blank one goes back to its default.
  def arranged(main:, aside:, hidden:, text: nil)
    sent = { "main" => clean(main), "aside" => (single_column? ? [] : clean(aside)), "hidden" => clean(hidden) - required_keys }
    sent["aside"] -= sent["hidden"]
    sent["main"] -= sent["aside"] + sent["hidden"]
    (keys - sent.values.flatten).each { |key| sent[zone_of(key)] << key }
    sent.merge("text" => text.nil? ? @text : @text.merge(clean_text(text, keep_blank: true)).compact_blank)
  end

  private
    def custom_fields = @custom_fields ||= (MODELS.fetch(kind) ? CustomField.for(MODELS.fetch(kind)).to_a : [])
    def all_keys = DEFAULTS[kind][:main] + DEFAULTS[kind][:aside] + custom_fields.map { "custom.#{it.key}" }

    def single_column? = SINGLE_COLUMN.include?(kind)

    # Only this kind's slots, as plain text; blank means back to the default (kept while merging a
    # page's edits, so clearing one there clears it).
    def clean_text(text, keep_blank: false)
      text.to_h.stringify_keys.slice(*TEXT_SLOTS[kind])
        .transform_values { ActionController::Base.helpers.strip_tags(it.to_s).squish.truncate(TEXT_LIMIT) }
        .then { keep_blank ? it : it.compact_blank }
    end
    def required_keys = DEFAULTS[kind][:required]
    def clean(list) = Array(list).map(&:to_s).uniq & all_keys

    # A saved arrangement reconciled with the fields there are now: unknown keys dropped, required
    # ones never hidden, and any not placed yet (new in this release, or a new custom field) in its
    # default column, at the end.
    def arrange(saved)
      saved = saved.to_h.stringify_keys
      placed = ZONES.index_with { clean(saved[it]) }
      placed["aside"] = [] if single_column?
      placed["hidden"] -= required_keys
      placed["aside"] -= placed["hidden"]
      placed["main"] -= placed["aside"] + placed["hidden"]
      (all_keys - placed.values.flatten).each { |key| placed[default_zone(key)] << key }
      placed.values_at(*ZONES)
    end

    # Custom fields start in the sidebar where the record's page is tabs (client, work), as Details
    # always showed them, and in the working column elsewhere.
    CUSTOM_IN_ASIDE = %w[client work].freeze

    def default_zone(key)
      return "main" if single_column?
      return "aside" if DEFAULTS[kind][:aside].include?(key) || (key.start_with?("custom.") && CUSTOM_IN_ASIDE.include?(kind))

      "main"
    end
    def zone_of(key) = { "main" => main, "aside" => aside, "hidden" => hidden }.find { |_, list| list.include?(key) }&.first || default_zone(key)
end
