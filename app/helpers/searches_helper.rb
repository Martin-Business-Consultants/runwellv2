module SearchesHelper
  # Where a result opens: the record's own page, or the page it lives on.
  def search_result_path(record)
    case record
    when Contact then client_path(record.client)
    when Task then task_path(record)
    when ScopeItem then scope_item_path(record)
    when Note then search_result_path(record.subject)
    when Document then search_result_path(record.documentable)
    else polymorphic_path(record)
    end
  end

  # The client a result belongs to, on the right of its row (its group names its kind).
  def search_result_context(record)
    search_client_names[record.search_client_id] unless record.is_a?(Client)
  end

  # Results by kind, the kinds in a fixed order (clients, work, tasks, then people, then the
  # rest), each kind's results in order of relevance. people: the team members who match.
  SEARCH_PRIORITY = %w[Client Work Task User Contact ScopeItem Note Document].freeze

  def search_result_groups(results, people: [])
    records = Array(results) + Array(people)
    records.group_by { it.class.name }
      .sort_by { |type, _| SEARCH_PRIORITY.index(type) || SEARCH_PRIORITY.size }
      .map { |_type, group| [ search_result_kind(group.first), group ] }
  end

  def search_result_kind(record)
    case record
    when Client then term(:client, count: 2)
    when Work then term(:work, count: 2)
    when Task then term(:task, count: 2)
    when ScopeItem then term(:scope_item, count: 2)
    when User then "People"
    else record.model_name.human.pluralize
    end
  end

  # A result's link: a task opens in the side panel (side_panel_link_to), anything else its page.
  def search_result_link_to(result, **options, &block)
    if result.is_a?(Task)
      side_panel_link_to(result, **options, &block)
    else
      link_to(search_result_path(result), data: { turbo_frame: "_top" }, **options, &block)
    end
  end

  # The search palette's items (searches/_palette): search_result_groups as ui :command's groups,
  # each result a link (a task's opening the side panel), then a line to every result on /search.
  def search_palette_items(results, query:, people:)
    groups = search_result_groups(results, people: people).to_h do |kind, group|
      [ kind, group.map { it.is_a?(User) ? search_palette_person(it) : search_palette_result(it) } ]
    end
    see_all = { label: "See all results for “#{query}”", value: "search:all", icon: icon_tag("search"), href: search_path(q: query), link: { data: { turbo_frame: "_top" } } }
    groups.merge("" => [ see_all ])
  end

  # A result's line of the match: the index's highlight as it is, else the record's own text with
  # its markup taken out (a description is rich text), cut short.
  def search_excerpt(content)
    content.html_safe? ? content : strip_tags(content.gsub("><", "> <")).squish.truncate(200)
  end

  def search_palette_result(result)
    content = result.hit.highlight(:content) || result.search_content.presence
    { label: result.hit.highlight(:title) || result.search_title, value: QuickAction.value_for(result),
      description: (search_excerpt(content) if content), meta: search_result_context(result),
      icon: icon_tag(search_result_icon(result)), href: (result.is_a?(Task) ? task_path(result) : search_result_path(result)),
      link: { data: (result.is_a?(Task) ? side_panel_link_data(result) : { turbo_frame: "_top" }) } }
  end

  def search_palette_person(person)
    { label: person.display_name, value: "User:#{person.id}", description: person.email_address, meta: person.role.capitalize,
      icon: person_tag(person), href: user_path(person), link: { data: { turbo_frame: "_top" } } }
  end

  SEARCH_ICONS = { "Client" => "everyone", "Contact" => "person", "Work" => "clipboard", "Task" => "check-circle",
    "ScopeItem" => "board", "Note" => "comment", "Document" => "attachment" }.freeze

  def search_result_icon(record) = SEARCH_ICONS.fetch(record.class.name, "search")

  # The clients of every result on the page, looked up once rather than per result.
  def search_client_names
    @search_client_names ||= Client.where(id: Array(@search&.results).filter_map { it.try(:search_client_id) }).pluck(:id, :name).to_h
  end
end
