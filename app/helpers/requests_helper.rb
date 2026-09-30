module RequestsHelper
  def request_summary(request_record)
    [ request_record.requester_name.presence || "Unknown sender",
      request_record.client&.name || "no client matched",
      request_record.source,
      "#{time_ago_in_words(request_record.received_at)} ago" ].join(" · ")
  end

  def request_engagement_options(request_record)
    engagements = request_record.client&.engagements&.open&.ordered || Engagement.none
    engagements.map { |engagement| [ "#{engagement.ref} #{engagement.title}", engagement.ref ] }
  end

  def promoted_path(target)
    case target
    when Engagement then engagement_path(target)
    when AgreementVersion, Todo then engagement_path(target.engagement)
    when Commitment then target.engagement ? engagement_path(target.engagement) : client_path(target.client)
    end
  end
end
