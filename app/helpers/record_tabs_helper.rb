# The tabs across a record page's working column (clients, work, tasks, scope items):
# the core's sections, one tab per plugin panel that's on, and History. A tab is a ?tab= link
# inside the record_tab frame, so it's bookmarkable, Back works, and only the tab reloads.
module RecordTabsHelper
  RecordTab = Data.define(:key, :label, :count, :partial)

  def record_tab(key, label, count: nil) = RecordTab.new(key: key, label: label, count: count, partial: nil)

  # One tab per plugin panel on this kind of page (the slot the sidebar used to hold).
  def plugin_record_tabs(slot)
    Runwell::Plugins.enabled_slots(slot).map do |key, partial|
      RecordTab.new(key: "plugin-#{key}", label: Runwell::Plugins.manifests[key].name, count: nil, partial: partial)
    end
  end

  def current_record_tab(tabs, default)
    params[:tab].presence_in(tabs.map(&:key)) || default
  end

  # The tabs as runeui's link tabs (layouts/shared/record_tabs): each loads only the record_tab
  # frame and advances history; a count sits beside its name.
  def record_tab_links(tabs)
    tabs.map do |tab|
      label = tab.count.to_i.positive? ? safe_join([ tab.label, tag.span(tab.count, class: "tab-count") ], " ") : tab.label
      { value: tab.key, label: label, href: record_tab_path(tab.key), data: { turbo_frame: "record_tab", turbo_action: "advance" } }
    end
  end

  # A section's filter as link tabs (layouts/shared/segmented_filter): each choice swaps one query
  # param, with its count beside it when given.
  def segmented_filter_links(param, options, counts: nil)
    options.map do |text, value|
      label = counts ? safe_join([ text, tag.span(counts.fetch(value, 0), class: "tab-count") ], " ") : text
      { value: value, label: label, href: url_for(request.query_parameters.merge(param.to_s => value)), data: { turbo_action: "replace" } }
    end
  end

  # Another tab closes the side panel: its link leaves ?task= out (and the side panel controller
  # lets the open panel fade away).
  def record_tab_path(key) = url_for(request.query_parameters.except("task", "peek").merge(tab: key))
end
