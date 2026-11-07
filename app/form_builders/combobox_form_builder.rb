# Every form's selects are comboboxes (the choices controller, Choices.js): select, time_zone_select,
# collection_select and grouped_collection_select add data-controller="choices" (beside any controller the field already has).
# combobox: false in the html options keeps a plain <select>.
class ComboboxFormBuilder < ActionView::Helpers::FormBuilder
  def select(method, choices = nil, options = {}, html_options = {}, &block)
    super(method, choices, options, combobox(html_options), &block)
  end

  def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
    super(method, priority_zones, options, combobox(html_options))
  end

  def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
    super(method, collection, value_method, text_method, options, combobox(html_options))
  end

  def grouped_collection_select(method, collection, group_method, group_label_method, option_key_method, option_value_method, options = {}, html_options = {})
    super(method, collection, group_method, group_label_method, option_key_method, option_value_method, options, combobox(html_options))
  end

  private
    def combobox(html_options)
      html_options = html_options.dup
      return html_options.except(:combobox) if html_options.delete(:combobox) == false

      data = (html_options[:data] || {}).dup
      data[:controller] = [ data[:controller], "choices" ].compact_blank.join(" ")
      html_options.merge(data: data)
    end
end
