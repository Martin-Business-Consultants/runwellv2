# A record that takes the install's custom fields (Client, Engagement, Todo). Values are
# assigned by field key, as the forms and agent tools send them:
#
#   client.update(custom_fields: { "website" => "acme.example", "renewal" => "2026-12-01" })
#
# Each is checked against its field's kind before the record saves; a blank removes it. Keys
# not given are left as they are.
module CustomFields
  extend ActiveSupport::Concern

  included do
    has_many :custom_values, as: :subject, dependent: :destroy
    validate :custom_field_inputs_fit
    after_save :save_custom_field_inputs
  end

  def custom_fields = CustomField.for(self.class.name)

  def custom_fields=(inputs)
    @custom_field_inputs = (inputs.respond_to?(:to_unsafe_h) ? inputs.to_unsafe_h : inputs.to_h).stringify_keys
  end

  # field → typed value, for every active field that has one.
  def custom_field_values
    values = custom_values.includes(:custom_field).index_by(&:custom_field_id)
    custom_fields.filter_map { |field| (value = values[field.id]) && [ field, field.cast(value.value) ] }
  end

  def custom_value(field) = custom_values.find { it.custom_field_id == field.id }&.then { field.cast(it.value) }

  # key → typed value, for agents.
  def custom_field_hash = custom_field_values.to_h { |field, value| [ field.key, value ] }

  # Plain text of every value, for search.
  def custom_search_text
    CustomValue.where(subject: self).pluck(:value).map { Rails::HTML5::FullSanitizer.new.sanitize(it) }.join(" ")
  end

  private
    def custom_field_inputs_fit
      return if @custom_field_inputs.blank?

      fields = custom_fields.index_by(&:key)
      @custom_field_writes = @custom_field_inputs.filter_map do |key, input|
        field = fields[key] or next errors.add(:base, "There’s no custom field “#{key}”")
        [ field, field.normalize(input) ]
      rescue ArgumentError => e
        errors.add(:base, "#{field.label} #{e.message}")
        nil
      end
    end

    def save_custom_field_inputs
      Array(@custom_field_writes).each do |field, text|
        value = custom_values.find_or_initialize_by(custom_field: field)
        text.nil? ? (value.destroy if value.persisted?) : value.update!(value: text)
      end
      @custom_field_inputs = @custom_field_writes = nil
      custom_values.reset
    end
end
