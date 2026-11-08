# Every form select is a combobox: Fizzy's (a button opening a popup of choices, the combobox or
# multi-selection-combobox controller writing hidden fields), drawn as the app's popups. It's built
# from the <select> Rails renders (ComboboxFormBuilder, or combobox_tag around a select_tag), so
# every way of giving choices, include_blank, selected, disabled and optgroups work as they do in
# a select. Nothing moves once on the page: the hidden fields and the chosen item come from the
# server, so a morph puts back what was saved. A pick fires change on its hidden field, so
# data-action="change->form#submit" (moved from the select to the wrapper) still saves on change.
module ComboboxHelper
  # Past this many choices, the popup opens with a box to filter them.
  COMBOBOX_FILTER_AT = 8

  def combobox_tag(&block)
    select = Nokogiri::HTML5.fragment(capture(&block)).at_css("select")
    return capture(&block) unless select

    combobox_from_select(select)
  end

  private
    def combobox_from_select(select)
      multiple = select.key?("multiple")
      options = select.css("option").map { combobox_option(it) }
      # Several choices: a blank one (include_blank) names choosing none, rather than being a choice.
      blank, options = options.partition { it[:value].blank? } if multiple
      none = blank&.first&.dig(:text) || "None"
      chosen = options.select { it[:selected] }
      chosen = [ options.find { !it[:disabled] } ].compact if chosen.empty? && !multiple
      label = select["aria-label"]
      field = { name: select["name"], form: select["form"], disabled: select.key?("disabled") }
      field_data = select.attributes.filter_map { |name, attr| [ name.delete_prefix("data-").underscore, attr.value ] if name.start_with?("data-") && name != "data-action" }.to_h

      controller = multiple ? "multi-selection-combobox" : "combobox"
      wrapper = tag.div(class: class_names("combobox", "combobox--sm": select["class"].to_s.include?("select--sm"), "combobox--multiple": multiple),
        data: {
          controller: "dialog #{controller} popup-filter navigable-list",
          action: [ "keydown.esc->dialog#close:stop", "click@document->dialog#closeOnClickOutside", "dialog:show->navigable-list#reset",
                    "dialog:close->popup-filter#clearInput", "keydown->navigable-list#navigate", "popup-filter:changed->navigable-list#reset", select["data-action"] ].compact.join(" "),
          dialog_orient_value: "false",
          combobox_blank_submits_value: ("true" unless multiple),
          multi_selection_combobox_no_selection_label_value: (none if multiple),
          multi_selection_combobox_connectors_value: ("{}" if multiple),
          navigable_list_actionable_items_value: "true", navigable_list_focus_on_selection_value: "false", navigable_list_auto_select_value: "false",
          navigable_list_supports_horizontal_navigation_value: "false", navigable_list_prevent_handled_keys_value: "true"
        }) do
        safe_join([
          *combobox_fields(field, multiple ? chosen.map { it[:value] } : [ chosen.first&.dig(:value).to_s ], controller, field_data),
          tag.button(type: "button", id: select["id"], class: "combobox__trigger", disabled: field[:disabled], autofocus: select.key?("autofocus"),
            aria: { haspopup: "listbox", label: label }, data: { action: "click->dialog#toggle:stop" }) do
            tag.span(chosen.map { it[:text] }.to_sentence.presence || none, class: "combobox__label", data: { "#{controller.underscore}_target": "label" }) + icon_tag("caret-down")
          end,
          tag.dialog(class: "popup combobox__popup", aria: { label: label }, data: { dialog_target: "dialog" }) do
            safe_join([ combobox_filter(options), tag.ul(combobox_items(options, chosen, controller, multiple), class: "popup__list", role: "listbox") ])
          end
        ])
      end
      # A multiple select sends an empty value first, as Rails' does, so choosing nothing clears it.
      multiple ? hidden_field_tag(field[:name], "", id: nil, form: field[:form], disabled: field[:disabled]) + wrapper : wrapper
    end

    def combobox_option(option)
      { value: option["value"] || option.text, text: option.text.strip, selected: option.key?("selected"), disabled: option.key?("disabled"),
        group: (option.parent["label"] if option.parent.name == "optgroup") }
    end

    # The fields the form sends: the chosen value (one), or one per choice (several), from the
    # server so a morph keeps them; the controller rewrites them as choices change.
    def combobox_fields(field, values, controller, data)
      target = controller == "combobox" ? { combobox_target: "field" } : {}
      fields = values.map { |value| hidden_field_tag(field[:name], value, id: nil, form: field[:form], disabled: field[:disabled], data: data.merge(target)) }
      template = tag.template(hidden_field_tag(field[:name], nil, id: nil, form: field[:form], data: data), data: { "#{controller.underscore}_target": "hiddenFieldTemplate" })
      [ *fields, template ]
    end

    def combobox_filter(options)
      return if options.size <= COMBOBOX_FILTER_AT

      search_field_tag(nil, nil, id: nil, placeholder: "Filter…", autocomplete: "off", aria: { label: "Filter the choices" },
        data: { "1p-ignore": "true", popup_filter_target: "input", dialog_target: "focusMouse", action: "input->popup-filter#filter" })
    end

    def combobox_items(options, chosen, controller, multiple)
      prefix = controller.underscore
      group = nil
      items = options.flat_map do |option|
        heading = (tag.li(option[:group], class: "popup__group", role: "presentation") if option[:group] && option[:group] != group)
        group = option[:group]
        item = tag.li(class: "popup__item", role: "checkbox", aria: { checked: chosen.include?(option) },
          data: { "#{prefix}_target": "item", navigable_list_target: "item", popup_filter_target: "item",
                  "#{prefix}_value": option[:value], "#{prefix}_label": option[:text] }) do
          tag.button(type: "button", class: "popup__btn", disabled: option[:disabled],
            data: { action: multiple ? "#{controller}#change" : "#{controller}#change dialog#close" }) do
            tag.span(option[:text], class: "popup__label") + icon_tag("check", class: "checked")
          end
        end
        [ heading, item ].compact
      end
      safe_join(items)
    end
end
