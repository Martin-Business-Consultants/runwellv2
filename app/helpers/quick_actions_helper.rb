module QuickActionsHelper
  # The record the page is about, for quick actions and plugins ("Start on …").
  def record_label(record)
    record.is_a?(ScopeItem) ? record.description : record.search_title
  end

  def record_type_term(type)
    case type
    when "Client" then term(:client)
    when "Work" then term(:work)
    when "ScopeItem" then term(:scope_item)
    when "Task" then term(:task)
    else type.titleize
    end
  end

  def record_types_term(type)
    key = { "Client" => :client, "Work" => :work, "ScopeItem" => :scope_item, "Task" => :task }[type]
    key ? term(key, count: 2) : type.titleize.pluralize
  end

  # A quick action's record picker (quick_actions/record_picker): the records it offers, by kind in
  # the order the kinds come (RECORD_TYPES), as ui :combobox options (["Clients", [[label, value]…]]).
  def quick_action_record_options(records)
    records.group_by { it.class.name }
      .sort_by { |type, _| QuickAction::RECORD_TYPES.index(type) || QuickAction::RECORD_TYPES.size }
      .map { |type, group| [ record_types_term(type), group.map { [ record_label(it), QuickAction.value_for(it) ] } ] }
  end

  # The same, as the JSON a combobox searching the server reads (quick_actions/records).
  def quick_action_record_items(records)
    quick_action_record_options(records).map do |kind, options|
      { type: "group", label: kind, items: options.map { |label, value| { value: value, label: label } } }
    end
  end
end
