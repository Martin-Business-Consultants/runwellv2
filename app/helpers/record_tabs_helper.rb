# The tabs across a record page's working column (clients, engagements, work, scope items):
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

  def record_tab_path(key) = url_for(request.query_parameters.merge(tab: key))
end
