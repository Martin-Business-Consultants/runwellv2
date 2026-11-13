# Runwell's default form builder: Rails' own field methods, drawn as runeui components, so a form
# (the core's or a plugin's) keeps calling form.select, form.text_field or form.check_box and gets
# the app's controls. form.ui :component, :attribute (runeui's) is there for anything else.
#
#   form.select and friends   ui :select, or ui :combobox for a long list, several choices or
#                             search: true (SelectHelper#select_control); combobox: false keeps a
#                             native <select>
#   form.text_field, email_field, url_field, telephone_field, number_field, password_field,
#   search_field              ui :input
#   form.text_area            ui :textarea
#   form.check_box            ui :checkbox (native: true keeps a plain checkbox)
class RunwellFormBuilder < ActionView::Helpers::FormBuilder
  def select(method, choices = nil, options = {}, html_options = {}, &block)
    control(html_options) { super(method, choices, options, it, &block) }
  end

  def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
    control(html_options) { super(method, priority_zones, options, it) }
  end

  def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
    control(html_options) { super(method, collection, value_method, text_method, options, it) }
  end

  def grouped_collection_select(method, collection, group_method, group_label_method, option_key_method, option_value_method, options = {}, html_options = {})
    control(html_options) { super(method, collection, group_method, group_label_method, option_key_method, option_value_method, options, it) }
  end

  INPUTS = { text_field: "text", email_field: "email", url_field: "url", telephone_field: "tel", number_field: "number", search_field: "search", password_field: "password" }.freeze

  INPUTS.each do |helper, type|
    define_method(helper) do |method, options = {}|
      options = options.symbolize_keys
      # A password never comes back from the record unless the caller hands it over (secret_field).
      options[:value] = nil if type == "password" && !options.key?(:value)
      ui(:input, method, type: type, **options)
    end
  end
  alias_method :phone_field, :telephone_field

  def text_area(method, options = {})
    ui(:textarea, method, **options.symbolize_keys)
  end
  alias_method :textarea, :text_area

  def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
    options = options.symbolize_keys
    return super(method, options.except(:native), checked_value, unchecked_value) if options[:native] || options[:role] == "switch"

    ui(:checkbox, method, value: checked_value, unchecked_value: (unchecked_value == false ? nil : unchecked_value),
      checked: (options.key?(:checked) ? options.delete(:checked) : object.try(method).then { it == true || it.to_s == checked_value.to_s }), **options)
  end
  alias_method :checkbox, :check_box

  private
    # html_options the control reads for itself: combobox: false (a native select), search: true
    # or false (a combobox whatever the list's length, or never).
    def control(html_options)
      html_options = html_options.symbolize_keys
      return yield(html_options.except(:combobox, :search)) if html_options[:combobox] == false

      @template.select_control(yield(html_options.except(:combobox, :search)), search: html_options[:search])
    end
end
