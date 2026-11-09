# A kind of work an install runs (Settings > Names > Types): its name, its plural, the prefix its
# refs start with (P-3, WO-12, S-4), and how its work runs. Project, work order and service are the
# system types, always there: they can be renamed, given another prefix or switched off (archived),
# never deleted. An owner adds any others.
#
# The key is set once from the name and never changes: a piece of work keeps it in works.label, and
# links, filters, agents and plugins name a type by it. A new prefix applies to new refs only (refs
# already given are in emails and links), and no two types share one, so refs never collide.
#
# How its work runs, which new work of the type starts with: its shape (fixed scope, delivered and
# then closed; or recurring, running until stopped), for recurring work how often (cadence) and
# whether it gets a check-in each period (a repeating task to look back on it), and the sections it
# starts with. A piece of work can still pick its own shape when it starts, and its own cadence.
#
# Its states: active (offered when starting work) or archived (not offered; work of the type keeps
# it). Deleting is only for a type nothing uses; merging moves its work onto another type, refs
# kept, and deletes it. Neither is open to a system type: `deletable?`, `mergeable?` say so first.
class WorkType < ApplicationRecord
  SYSTEM_KEYS = %w[project work_order service].freeze
  SHAPES = { "fixed" => "Fixed scope", "recurring" => "Recurring" }.freeze

  # A move the type's state doesn't allow (deleting a system type or one in use, merging into
  # itself), refused in words by the verb.
  class Refused < StandardError; end

  positioned

  normalizes :name_one, :name_other, with: ->(name) { name.to_s.squish }
  normalizes :prefix, with: ->(prefix) { prefix.to_s.upcase.gsub(/[^A-Z0-9]/, "") }
  normalizes :description, with: ->(text) { text.to_s.strip.presence }
  normalizes :cadence, with: ->(cadence) { cadence.to_s.presence }
  normalizes :starting_sections, with: ->(sections) { (sections.is_a?(String) ? sections.split(/\r?\n|,/) : Array(sections)).map { it.to_s.squish }.compact_blank.uniq.first(20).presence }

  validates :name_one, presence: true, length: { maximum: 40 }
  validates :name_other, presence: true, length: { maximum: 40 }
  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :prefix, presence: true, length: { maximum: 4 }, uniqueness: { message: "is already another type’s" }
  validates :shape, inclusion: { in: SHAPES.keys }
  validates :cadence, inclusion: { in: Cadence::KEYS }, allow_nil: true
  validate :key_is_fixed, on: :update
  validate :system_type_stays, on: :update

  before_validation :name_plural, :key_from_name, on: :create
  before_validation :tidy_for_shape
  after_commit { Current.work_types = nil }

  scope :ordered, -> { order(:position) }
  scope :active, -> { where(archived_at: nil) }

  # Every type, in order, read once per request (refs, names and pickers ask for them per row).
  def self.cached = Current.work_types ||= ordered.to_a.presence || ensure_system!
  def self.keys = cached.map(&:key)
  def self.active_keys = cached.reject(&:archived?).map(&:key)
  def self.named(key) = cached.find { it.key == key.to_s }

  # The system types, put back if they're missing (an emptied database, before seeds): each with
  # its default names, prefix and shape. Returns every type.
  def self.ensure_system!
    defaults = I18n.t("terms.labels")
    SYSTEM_KEYS.each do |key|
      next if exists?(key: key)

      create!(key: key, system: true, name_one: defaults.dig(key.to_sym, :one), name_other: defaults.dig(key.to_sym, :other),
        prefix: defaults.dig(key.to_sym, :prefix), shape: key == "service" ? "recurring" : "fixed", cadence: ("monthly" if key == "service"))
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      next
    end
    ordered.to_a
  end

  # By its key (what links and agents use), else its id or its name.
  def self.locate!(value)
    value = value.to_s
    find_by(key: value) || (value.match?(/\A\d+\z/) && find_by(id: value)) || where("lower(name_one) = ?", value.downcase).first or raise ActiveRecord::RecordNotFound, "No work type “#{value}”"
  end

  def to_param = key

  def name(count: 1) = count == 1 ? name_one : name_other
  def archived? = archived_at.present?
  def recurring? = shape == "recurring"
  def shape_name = SHAPES.fetch(shape)
  def cadence_name = Cadence.name(cadence)

  # "Recurring, monthly, with a check-in" / "Fixed scope": how its work runs, in words.
  def runs
    return shape_name unless recurring?

    [ shape_name, cadence_name&.downcase, ("check-in each #{Cadence.period(cadence)}" if check_in? && cadence) ].compact.join(", ")
  end

  def works = Work.where(label: key)
  def works_count = @works_count ||= works.count
  attr_writer :works_count

  def deletable? = !system? && works_count.zero?
  def mergeable? = !system?

  def archive! = archived? ? true : update!(archived_at: Time.current)
  def restore! = archived? ? update!(archived_at: nil) : true

  def destroy_unused!
    raise Refused, "#{name_one} is a system type: switch it off (archive it) instead." if system?
    raise Refused, "#{name_one} is in use (#{pluralize_works}): switch it off, or merge it into another type." unless works_count.zero?

    destroy!
  end

  # Its work moves onto `into` (refs kept, each recording work.retyped), then it goes.
  def merge_into!(into, actor: Current.user, source: Current.source || "app")
    raise Refused, "#{name_one} is a system type: switch it off (archive it) instead." if system?
    raise Refused, "Pick another type to merge #{name_one} into." if into.nil? || into == self

    transaction do
      works.find_each { it.retype!(into.key, actor: actor, source: source) }
      destroy!
    end
  end

  private
    def pluralize_works
      "#{works_count} #{Setting.current.term(:work, count: works_count).downcase}"
    end

    def name_plural
      self.name_other = name_one.to_s.pluralize if name_other.blank? && name_one.present?
    end

    # From the name ("Retainer" → retainer), made unique with a number when another type has it.
    def key_from_name
      return if key.present?

      base = name_one.to_s.parameterize(separator: "_").gsub(/[^a-z0-9_]/, "").sub(/\A[^a-z]+/, "").presence || "type"
      candidate, n = base, 1
      candidate = "#{base}_#{n += 1}" while WorkType.exists?(key: candidate) || candidate.in?(%w[all none])
      self.key = candidate
    end

    def tidy_for_shape
      return if recurring?

      self.cadence = nil
      self.check_in = false
    end

    def key_is_fixed
      errors.add(:key, "can’t change once it’s made") if key_changed?
    end

    def system_type_stays
      errors.add(:system, "can’t change") if system_changed?
    end
end
