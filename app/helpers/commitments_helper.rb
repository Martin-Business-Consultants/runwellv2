module CommitmentsHelper
  # Who can own a commitment for this client: us (or one of us), the client (or one of its contacts).
  def commitment_owner_options(client)
    {
      "Us" => [ [ "Us", "us" ] ] + User.active.ordered.map { |user| [ user.display_name, "user:#{user.id}" ] },
      client.name => [ [ client.name, "client" ] ] + client.contacts.active.ordered.map { |contact| [ contact.name, "contact:#{contact.id}" ] }
    }
  end

  # Whose promise it is: one of us as their avatar, otherwise "Us", the client or a contact by name.
  def commitment_owner(commitment)
    commitment.owner_kind == "us" && commitment.user ? person_tag(commitment.user) : commitment.owner_name
  end

  def commitment_details(commitment, with_context: false)
    safe_join([
      (commitment.client.name if with_context),
      (commitment.engagement&.ref if with_context),
      safe_join([ commitment.owner_kind == "us" ? "Ours: " : "Theirs: ", commitment_owner(commitment) ]),
      "due #{l commitment.due_on, format: :short}",
      commitment.source
    ].compact, " · ")
  end
end
