# What the JSON views show agents. Every record carries `record` ("Client:12"), which the
# tools that take a record accept, and `url`, its page for the person reading along.
module AgentHelper
  def agent_ref(record)
    return if record.nil?

    { "type" => record.class.name, "id" => record.id, "record" => "#{record.class.name}:#{record.id}", "ref" => record.try(:ref),
      "display_name" => agent_label(record), "url" => agent_url(record) }.compact
  end

  def agent_label(record)
    case record
    when AgreementVersion then "#{record.engagement.ref} #{record.label}"
    when ScopeItem then record.description
    when Question then record.text
    when User then record.display_name
    else record.try(:search_title) || record.try(:label) || record.try(:name) || "#{record.class.name} #{record.id}"
    end
  end

  def agent_url(record)
    path = case record
    when Question then root_path
    when User then nil
    else search_result_path(record)
    end
    request.base_url + path if path
  rescue NoMethodError, ActionController::UrlGenerationError
    nil
  end

  def agent_user(user) = user && { "id" => user.id, "name" => user.display_name }

  # Plain text from a rich text column, for a model to read.
  def agent_text(html) = html.presence && strip_tags(html.to_s.gsub(%r{<br\s*/?>|</p>|</li>}i, "\n")).squeeze("\n").strip
end
