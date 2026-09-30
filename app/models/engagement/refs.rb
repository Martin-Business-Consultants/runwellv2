# Human refs like WO-12, P-3, S-4: one sequence per label. The prefix comes from Settings >
# Names; changing it applies to new refs only, since sent agreements carry their ref.
module Engagement::Refs
  extend ActiveSupport::Concern

  included do
    before_validation :assign_ref, on: :create
    validates :ref, presence: true, uniqueness: true
  end

  class_methods do
    def find_by_ref!(ref) = find_by!(ref: ref.to_s.upcase)
  end

  private

  def assign_ref
    return if ref.present?
    return unless label.in?(Engagement::LABELS)

    prefix = Setting.current.label_prefix(label)
    last = Engagement.where("ref LIKE ?", "#{prefix}-%")
                     .pluck(:ref).map { |r| r.split("-").last.to_i }.max || 0
    self.ref = "#{prefix}-#{last + 1}"
  end
end
