# Something an install records about its clients, work or tasks that the core doesn't
# (Settings > Fields). Information only: nothing in Runwell acts on a custom field, so anything
# that needs behaviour is a real column or a plugin's own table. Optional, never required; a
# field that's no longer wanted is archived, keeping its values, so history still reads right.
# The key is set once from the label and never changes, so agents and imports can rely on it.
#
# Who sees it: everyone on staff, or only some roles (visible_to; owners see every field). That's
# a permission, not a layout: CustomField.for leaves a field out for anyone else, so their pages,
# the side panel, tables, agents and saves never see or set it; search indexes only fields everyone
# sees, and a restricted field never reaches the client portal.
class CustomField < ApplicationRecord
  MODELS = %w[Client Work Task].freeze
  KINDS = %w[text long_text number money date boolean choice link].freeze
  KIND_LABELS = { "text" => "Text", "long_text" => "Long text", "number" => "Number", "money" => "Money", "date" => "Date",
    "boolean" => "Yes or no", "choice" => "Choice", "link" => "Link" }.freeze

  has_many :values, class_name: "CustomValue", dependent: :destroy
  positioned on: :model_type

  # The roles that may see a field besides owners, who see every one.
  RESTRICTABLE_ROLES = User::ROLES - %w[owner]

  normalizes :label, with: ->(value) { value.to_s.strip }
  # The roles besides owners who see it: every one is everyone (nil); none is owners only ([]).
  normalizes :visible_to, with: ->(roles) { (Array(roles).map(&:to_s) & RESTRICTABLE_ROLES).then { it.size == RESTRICTABLE_ROLES.size ? nil : it } }
  normalizes :choices, with: ->(value) { Array(value.is_a?(String) ? value.split(/[\n,]/) : value).map { it.to_s.strip }.compact_blank.uniq }

  validates :model_type, inclusion: { in: MODELS }
  validates :kind, inclusion: { in: KINDS }
  validates :label, presence: true
  validates :key, presence: true, uniqueness: { scope: :model_type, message: "is already used by another field" }
  validates :choices, presence: { message: "are needed for a choice field" }, if: -> { kind == "choice" }
  validate :kind_is_fixed, on: :update

  before_validation(on: :create) { self.key = label.to_s.parameterize(separator: "_").presence if key.blank? }
  # A field only some of the team may see is never shown to clients.
  before_save { self.client_visible = false unless everyone? }

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(:position) }
  scope :listed, -> { where(listed: true) }

  # The fields someone may see: every one for owners and for no one in particular (a job, an
  # import, the portal, which filters by client_visible); for anyone else on staff (or their
  # agent), those for everyone and those naming their role.
  scope :seen_by, ->(user) {
    person = user&.person
    next all if person.nil? || person.owner?

    where("custom_fields.visible_to IS NULL OR EXISTS (SELECT 1 FROM json_each(custom_fields.visible_to) WHERE json_each.value = ?)", person.role)
  }
  scope :for_everyone, -> { where(visible_to: nil) }

  def self.for(model, viewer: Current.user) = active.where(model_type: model.to_s).seen_by(viewer).ordered

  # Every date field's value that falls in a range of dates, as the viewer may see them: a list of
  # [record, field, date], each record a Client, Work or Task (a work's launch, a client's renewal).
  # What a calendar reads (the plugin contract, 5.5); one query for the values, one per kind of record.
  def self.dates_between(range, viewer: Current.user)
    fields = active.where(kind: "date").seen_by(viewer).index_by(&:id)
    return [] if fields.empty?

    CustomValue.where(custom_field_id: fields.keys, value: range.first.iso8601..range.last.iso8601).includes(:subject)
      .filter_map { |value| value.subject && [ value.subject, fields.fetch(value.custom_field_id), Date.iso8601(value.value) ] }
  end

  def everyone? = visible_to.nil?
  def seen_by_role?(role) = role == "owner" || everyone? || visible_to.include?(role)

  # Who sees it, in words: "Everyone", or "Owners and managers".
  def visible_to_label
    return "Everyone" if everyone?

    ([ "owners" ] + visible_to.map { "#{it}s" }).to_sentence.capitalize.then { visible_to.empty? ? "Owners only" : it }
  end

  def archived? = archived_at.present?
  def kind_label = KIND_LABELS.fetch(kind)

  # What an input becomes in the column (text), or nil for blank. Raises ArgumentError, in
  # words, for something this kind can't hold. Money arrives as whole cents.
  def normalize(input)
    input = input.to_s.strip
    return nil if input.blank? && kind != "boolean"

    case kind
    when "text" then input.truncate(500)
    when "long_text" then input
    when "number"
      raise ArgumentError, "should be a number" unless input.match?(/\A-?\d+(\.\d+)?\z/)
      input
    when "money"
      raise ArgumentError, "should be whole cents, like 150000 for $1,500.00" unless input.match?(/\A-?\d+\z/)
      input.to_i.to_s
    when "date"
      Date.iso8601(input).iso8601
    when "boolean" then ActiveModel::Type::Boolean.new.cast(input) ? "true" : "false"
    when "choice"
      raise ArgumentError, "should be one of #{choices.to_sentence(two_words_connector: " or ", last_word_connector: " or ")}" unless choices.include?(input)
      input
    when "link"
      url = input.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? input : "https://#{input}"
      raise ArgumentError, "should be a web address" unless url.match?(%r{\Ahttps?://[^\s/]+\.[^\s]+\z}i)
      url
    end
  rescue Date::Error
    raise ArgumentError, "should be a date, YYYY-MM-DD"
  end

  # The stored text as a Ruby value: Integer cents, BigDecimal, Date, true/false or String.
  def cast(text)
    return nil if text.nil?

    case kind
    when "money" then text.to_i
    when "number" then text.include?(".") ? BigDecimal(text) : text.to_i
    when "date" then Date.iso8601(text)
    when "boolean" then text == "true"
    else text
    end
  end

  private
    def kind_is_fixed
      errors.add(:kind, "can’t change once values exist: add a new field instead") if kind_changed? && values.exists?
    end
end
