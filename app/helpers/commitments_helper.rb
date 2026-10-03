module CommitmentsHelper
  # Who can make a promise, on either side: you and your people, the client and its contacts.
  def commitment_owner_options(client)
    {
      "Your side" => [ [ "We", "us" ] ] + User.active.people.ordered.map { |user| [ user.display_name, "user:#{user.id}" ] },
      client.name => [ [ client.name, "client" ] ] + client.contacts.active.ordered.map { |contact| [ contact.name, "contact:#{contact.id}" ] }
    }
  end

  # Whose promise it is: one of us as their avatar, otherwise "Us", the client or a contact by name.
  def commitment_owner(commitment)
    commitment.owner_kind == "us" && commitment.user ? person_tag(commitment.user) : commitment.owner_name
  end

  # A commitment as the sentence it is: "Rosa will send the logo", "We will send the proposal".
  def commitment_sentence(commitment)
    safe_join([ tag.strong(commitment_promiser(commitment)), " will ", commitment_action(commitment) ])
  end

  def commitment_promiser(commitment)
    commitment.owner_kind == "us" ? (commitment.user&.display_name || "We") : (commitment.contact&.name || commitment.client.name)
  end

  # The promise itself, read after "will": its first letter lowered unless it starts an acronym.
  def commitment_action(commitment) = commitment.description.sub(/\A\p{Upper}(?=\p{Lower})/, &:downcase)

  # By when, or how it ended.
  def commitment_when(commitment)
    if commitment.open?
      commitment.overdue? ? "overdue since #{l commitment.due_on, format: :short}" : "by #{l commitment.due_on, format: :short}"
    else
      "#{commitment.resolution} #{l commitment.resolved_at.to_date, format: :short}"
    end
  end

  def commitment_details(commitment, with_context: false)
    safe_join([
      (commitment.client.name if with_context),
      (commitment.engagement&.ref if with_context),
      commitment_when(commitment),
      commitment.source.presence
    ].compact, " · ")
  end

  # The two lanes every list of commitments shows: what the other side owes you, and what you've
  # promised them.
  def commitment_lanes(commitments) = commitments.partition { it.owner_kind == "client" }

  def waiting_on_title(client = nil) = client ? "Waiting on #{client.name}" : "Waiting on them"
end
