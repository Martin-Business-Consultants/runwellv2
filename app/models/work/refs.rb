# Human refs like WO-12, P-3, S-4: one sequence per prefix. The prefix is the work's type's
# (WorkType, Settings > Names > Types); changing it applies to new refs only, since refs already
# given are in emails and links.
module Work::Refs
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
    prefix = Setting.current.label_prefix(label) or return

    last = Work.where("ref LIKE ?", "#{prefix}-%").maximum(Arel.sql("CAST(substr(ref, #{prefix.length + 2}) AS INTEGER)")) || 0
    self.ref = "#{prefix}-#{last + 1}"
  end

  # Two pieces of work started at once can both take the next number: the unique index refuses
  # the second, which takes the one after and tries once more.
  def _create_record(*)
    super
  rescue ActiveRecord::RecordNotUnique => error
    raise if @ref_retried || !error.message.include?("works.ref")

    @ref_retried = true
    self.ref = nil
    assign_ref
    retry
  end
end
