# Template mode (RecordLayout): each kind of record's arrangement of fields, set by owners on the
# record's own pages, recorded in the audit log.
module Setting::Layouts
  extend ActiveSupport::Concern

  def layout(kind) = RecordLayout.new(kind, layouts.to_h[kind.to_s])

  def arrange_layout!(kind, main:, aside:, hidden:, text: nil)
    arranged = layout(kind).arranged(main: main, aside: aside, hidden: hidden, text: text)
    update!(layouts: layouts.to_h.merge(kind.to_s => arranged))
    record_event!("settings.layout", payload: { kind: kind.to_s, layout: arranged })
  end

  # The sidebar (NavLayout, Settings > Sidebar): sections, their labels and order, and what's hidden.
  def nav_layout = NavLayout.new(layouts.to_h["nav"])

  def arrange_nav!(sections:, hidden: [])
    arranged = nav_layout.arranged(sections: sections, hidden: hidden)
    update!(layouts: layouts.to_h.merge("nav" => arranged))
    record_event!("settings.layout", payload: { kind: "nav", layout: arranged })
  end

  def reset_nav!
    update!(layouts: layouts.to_h.except("nav"))
    record_event!("settings.layout", payload: { kind: "nav", reset: true })
  end

  def reset_layout!(kind)
    update!(layouts: layouts.to_h.except(kind.to_s))
    record_event!("settings.layout", payload: { kind: kind.to_s, reset: true })
  end
end
