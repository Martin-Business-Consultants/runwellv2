# The install's time zone: what your pages, agent answers and emails use (a client may have its own,
# Client#time_zone). Saved here it wins over TIME_ZONE in the environment, which is the default.
module Setting::TimeZone
  extend ActiveSupport::Concern

  included do
    validates :time_zone, inclusion: { in: ->(_) { ActiveSupport::TimeZone.all.map(&:name) + TZInfo::Timezone.all_identifiers }, message: "isn’t a time zone we know" }, allow_nil: true
    normalizes :time_zone, with: ->(value) { value.presence && (ActiveSupport::TimeZone::MAPPING.key(value) || value) }
  end

  class_methods do
    def zone = ActiveSupport::TimeZone[current.time_zone.presence || Time.zone_default.name] || Time.zone_default
    def time_zone_set? = current.time_zone.present? || ENV["TIME_ZONE"].present?
  end
end
