# Something an install records about its clients, engagements or work that the core doesn't
# (Settings > Fields). Information only: nothing in Runwell acts on a custom field, so anything
# that needs behaviour is a real column or a plugin's own table. Optional, never required; a
# field that's no longer wanted is archived, keeping its values, so history still reads right.
# The key is set once from the label and never changes, so agents and imports can rely on it.
class CustomField < ApplicationRecord
  MODELS = %w[Client Engagement Todo].freeze
  KINDS = %w[text long_text number money date boolean choice link].freeze
  KIND_LABELS = { "text" => "Text", "long_text" => "Long text", "number" => "Number", "money" => "Money", "date" => "Date",
    "boolean" => "Yes or no", "choice" => "Choice", "link" => "Link" }.freeze

  has_many :values, class_name: "CustomValue", dependent: :destroy
  positioned on: :model_type

  normalizes :label, with: ->(value) { value.to_s.strip }
  normalizes :choices, with: ->(value) { Array(value.is_a?(String) ? value.split(/[\n,]/) : value).map { it.to_s.strip }.compact_blank.uniq }

  validates :model_type, inclusion: { in: MODELS }
  validates :kind, inclusion: { in: KINDS }
  validates :label, presence: true
  validates :key, presence: true, uniqueness: { scope: :model_type, message: "is already used by another field" }
  validates :choices, presence: { message: "are needed for a choice field" }, if: -> { kind == "choice" }
  validate :kind_is_fixed, on: :update

  before_validation(on: :create) { self.key = label.to_s.parameterize(separator: "_").presence if key.blank? }

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(:position) }
  scope :listed, -> { where(listed: true) }

  def self.for(model) = active.where(model_type: model.to_s).ordered

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
