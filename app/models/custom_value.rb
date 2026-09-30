# One record's value for one custom field, as text (money in whole cents, dates ISO 8601).
class CustomValue < ApplicationRecord
  belongs_to :custom_field
  belongs_to :subject, polymorphic: true

  validates :value, presence: true

  def typed = custom_field.cast(value)
end
