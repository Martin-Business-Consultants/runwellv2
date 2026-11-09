# The sidebar's arrangement for the whole install (Settings > Sidebar), set by whoever manages
# settings, as template mode arranges a record's fields: named sections in order, each holding nav
# items in order, and a Hidden tray. It's kept in Setting#layouts under "nav" (beside the record
# layouts), so it needs no table of its own.
#
# An item is a core section ("clients", "works", "tasks", "users") or a plugin's page ("plugin.<key>",
# from Runwell::Plugins.nav). Plugins sit among the core's sections, wherever they're put, with no
# "Plugins" heading of their own. One switched on after the sidebar was arranged joins the end of
# the first section until it's moved. One switched off drops out of sight and keeps its place (at
# the end of the first section, once the sidebar is arranged again meanwhile), so switching it back
# on puts it back. A section's label may be blank (no heading over it); a section with nothing to
# show is left out of the sidebar.
class NavLayout
  CORE = %w[clients works tasks users].freeze
  LABEL_MAX = 40
  DEFAULT = { "sections" => [ { "label" => "Workspace", "items" => CORE } ], "hidden" => [] }.freeze

  def self.current = new(Setting.current.layouts.to_h["nav"])

  # Every item that can be placed now: the core's, then each switched-on plugin with a page.
  def self.available = CORE + Runwell::Plugins.enabled_nav_items.keys.map { "plugin.#{it}" }

  # The plugin's key for a plugin's item ("plugin.calendar" → :calendar), nil for a core one.
  def self.plugin_key(item) = (item.to_s.delete_prefix("plugin.").to_sym if item.to_s.start_with?("plugin."))

  def initialize(saved)
    @saved = saved.presence || DEFAULT
  end

  def customized? = @saved != DEFAULT

  # The sections as they stand: [{ "label" =>, "items" => [...] }], with only items that exist now,
  # and any not yet placed at the end of the first section.
  def sections(available = self.class.available)
    placed = saved_sections.flat_map { it["items"] } + hidden(available)
    sections = saved_sections.map { { "label" => it["label"], "items" => it["items"] & available } }
    sections = [ { "label" => "", "items" => [] } ] if sections.empty?
    sections.first["items"] += available - placed
    sections
  end

  def hidden(available = self.class.available) = Array(@saved["hidden"]).map(&:to_s) & available

  # A new arrangement from what was sent (Settings > Sidebar, or the arrange_sidebar tool): labels
  # trimmed, each known item once (the first place it's named), unknown ones dropped. Items left
  # out stay where they were saved, hidden ones or not, so an arrangement made while a plugin was off
  # doesn't lose it. Raises ArgumentError, in words, for nothing to arrange.
  def arranged(sections:, hidden: [], available: self.class.available)
    seen = Set.new
    take = ->(items) { Array(items).map(&:to_s).select { available.include?(it) && seen.add?(it) } }
    sections = Array(sections).map { |section| section.to_h.stringify_keys }.map do |section|
      { "label" => section["label"].to_s.squish.truncate(LABEL_MAX, omission: ""), "items" => take.(section["items"]) }
    end
    raise ArgumentError, "Give the sidebar at least one section" if sections.empty?

    hidden = take.(hidden)
    # What wasn't sent (a plugin that's off now) keeps its saved place.
    kept_hidden = Array(@saved["hidden"]).map(&:to_s) - available
    { "sections" => sections.each_with_index.map { |section, index| index.zero? ? section.merge("items" => section["items"] + offstage_items) : section },
      "hidden" => hidden + kept_hidden }
  end

  def to_h = { "sections" => sections, "hidden" => hidden }

  private
    def saved_sections
      Array(@saved["sections"]).map { { "label" => it["label"].to_s, "items" => Array(it["items"]).map(&:to_s) } }
    end

    # Items saved in a section that aren't available now (a plugin switched off), kept for when
    # they're back.
    def offstage_items = saved_sections.flat_map { it["items"] } - self.class.available
end
