# Template mode (RecordLayout): each kind of record's arrangement of fields, set by owners on the
# record's own pages, recorded in the audit log.
module Setting::Layouts
  extend ActiveSupport::Concern

  def layout(kind) = RecordLayout.new(kind, layouts.to_h[kind.to_s])

  def arrange_layout!(kind, main:, aside:, hidden:)
    arranged = layout(kind).arranged(main: main, aside: aside, hidden: hidden)
    update!(layouts: layouts.to_h.merge(kind.to_s => arranged))
    record_event!("settings.layout", payload: { kind: kind.to_s, layout: arranged })
  end

  def reset_layout!(kind)
    update!(layouts: layouts.to_h.except(kind.to_s))
    record_event!("settings.layout", payload: { kind: kind.to_s, reset: true })
  end
end
