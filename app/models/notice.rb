# Who hears about what passes between a client and the team, in one place. The core says who would
# usually hear (`usual`) and who could at all (`everyone`: a client's people who can sign in to the
# portal and still want its mail; the team's active people); a plugin that's on may then choose
# among them (Runwell::Plugins.notices), per client, and the answer never leaves `everyone`.
#
# To a client's people, by email (PortalMailer): a message from the team on a task (reply),
# something they asked for taken on or done, and files shared with them (document). To the team, as
# notifications (Notifier): a request from outside, and a client's reply on a task.
module Notice
  CLIENT_KINDS = {
    "reply" => "We write to them on a task",
    "taken_on" => "Something they asked for is picked up",
    "done" => "Something they asked for is done",
    "document" => "We share a file with them"
  }.freeze
  TEAM_KINDS = {
    "request" => "A request comes in",
    "reply" => "They write to us on a task"
  }.freeze

  class << self
    # The client's people to email about `record` (a Note, Task or Document).
    def contacts(kind, client:, record:, usual:)
      return [] unless client

      # Nobody is told about something they can't see in the portal (Contact::PortalScope). Files
      # go out several at once, so SharedDocumentsJob checks each one per person instead.
      everyone = reachable_contacts(client)
      everyone = everyone.select { it.sees?(record) } unless record.nil? || record.is_a?(Document)
      Runwell::Plugins.notice_recipients(:client, kind: kind.to_s, client: client, record: record, usual: Array(usual) & everyone, everyone: everyone)
    end

    # The team's people to notify about `record` (a Task or Note). client: nil for a request
    # emailed by someone not on file.
    def people(kind, client:, record:, usual:)
      everyone = User.people.active.to_a
      Runwell::Plugins.notice_recipients(:team, kind: kind.to_s, client: client, record: record, usual: Array(usual) & everyone, everyone: everyone)
    end

    # A client's people who may sign in to the portal and haven't switched its mail off.
    def reachable_contacts(client)
      Contact.with_portal_access.where(client_id: client.id, portal_emails: true).where.not(email_address: [ nil, "" ]).order(:name).to_a
    end
  end
end
