# Every form's selects are comboboxes (ComboboxHelper: Fizzy's popup of choices, built from the
# <select> Rails renders). combobox: false keeps a plain <select>.
class ComboboxFormBuilder < ActionView::Helpers::FormBuilder
  def select(method, choices = nil, options = {}, html_options = {}, &block)
    combobox(html_options) { super(method, choices, options, it, &block) }
  end

  def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
    combobox(html_options) { super(method, priority_zones, options, it) }
  end

  def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
    combobox(html_options) { super(method, collection, value_method, text_method, options, it) }
  end

  def grouped_collection_select(method, collection, group_method, group_label_method, option_key_method, option_value_method, options = {}, html_options = {})
    combobox(html_options) { super(method, collection, group_method, group_label_method, option_key_method, option_value_method, options, it) }
  end

  private
    def combobox(html_options)
      html_options = html_options.dup
      return yield(html_options.except(:combobox)) if html_options.delete(:combobox) == false

      @template.combobox_tag { yield(html_options) }
    end
end
