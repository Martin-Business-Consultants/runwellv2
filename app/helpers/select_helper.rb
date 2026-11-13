# Every select is a runeui control, built from the <select> Rails renders (RunwellFormBuilder, or
# select_control around a select_tag), so every way of giving choices, include_blank, selected,
# disabled and optgroups work as they do in a select:
#
#   a short list                       ui :select
#   a long one (more than SEARCH_OVER  ui :combobox, trigger: true: a button like a select's, the
#   choices), several (multiple), or  box to search its choices in its popup
#   search: true
#
# The control is form-associated: it sends its value under the select's name (each choice of a
# multiple as its own entry, after an empty one, as Rails does, so choosing nothing clears it),
# joins a form it sits outside of by form:, and fires change as it's picked, so the select's
# data-action (change->form#submit) works where it is. Its value comes from the server
# (default-value), so a morph keeps what someone picked unless the server's changed.
module SelectHelper
  SEARCH_OVER = 7

  # The name plugins call (the plugin contract, 5.7.2): combobox_tag { select_tag … }.
  def combobox_tag(search: nil, &block) = select_control(capture(&block), search: search)

  def select_control(html, search: nil)
    select = Nokogiri::HTML5.fragment(html).at_css("select")
    return html unless select

    multiple = select.key?("multiple")
    groups, blank = select_choices(select, multiple)
    flat = groups.flat_map { it.is_a?(Hash) ? it.values.first : [ it ] }
    chosen = flat.select { it[2][:selected] }.map { it[1] }
    required = select.key?("required")
    # A select shows its first choice when nothing's chosen; so does this, unless it may be blank.
    chosen = [ flat.find { !it[2][:disabled] }&.dig(1) ].compact if chosen.empty? && !multiple && blank.nil?
    # data-combobox-filter (5.7.1, when only some had the box) still asks for the box.
    search = true if search.nil? && select["data-combobox-filter"]
    searchable = search.nil? ? (multiple || flat.size > SEARCH_OVER) : (search || multiple)

    attrs = { name: select["name"], id: select["id"], form: select["form"], disabled: select.key?("disabled"), required: required,
      size: (:sm if select["class"].to_s.include?("select--sm")), options: select_options(groups), value: (multiple ? chosen : chosen.first),
      placeholder: blank || (multiple ? "None" : nil), data: select_data(select), aria: { label: select["aria-label"] }.compact.presence }.compact
    # Choosing nothing is a choice in the list, as in a select (not one that must be filled in).
    attrs[:options] = [ [ blank, "" ] ] + attrs[:options] if blank && !required && !multiple
    control = searchable ? ui(:combobox, **attrs, multiple: multiple, trigger: true, search: "Search…") : ui(:select, **attrs)
    # What's sent when nothing is chosen: an empty value, ahead of the control's own.
    empty = multiple || (!blank.nil? && !required)
    empty ? hidden_field_tag(select["name"], "", id: nil, form: select["form"], disabled: select.key?("disabled"), autocomplete: "off") + control : control
  end

  private
    # The select's options as [label, value, { disabled:, selected: }], optgroups as { label => [...] },
    # and the blank choice's words (include_blank, prompt), taken out: it names choosing nothing.
    def select_choices(select, multiple)
      blank = nil
      read = lambda do |option|
        value = option["value"] || option.text
        if value.blank?
          blank ||= option.text.strip.presence || (multiple ? "None" : "")
          next
        end
        [ option.text.strip, value, { disabled: option.key?("disabled"), selected: option.key?("selected") } ]
      end
      groups = select.element_children.filter_map do |child|
        child.name == "optgroup" ? { child["label"] => child.css("option").filter_map(&read) } : read.(child)
      end
      [ groups, blank ]
    end

    def select_options(groups)
      groups.map { it.is_a?(Hash) ? [ it.keys.first, it.values.first.map { |label, value, flags| [ label, value, flags.slice(:disabled) ] } ] : [ it[0], it[1], it[2].slice(:disabled) ] }
    end

    def select_data(select)
      select.attributes.filter_map { |name, attr| [ name.delete_prefix("data-").underscore.to_sym, attr.value ] if name.start_with?("data-") && name != "data-combobox-filter" }.to_h.presence
    end
end
