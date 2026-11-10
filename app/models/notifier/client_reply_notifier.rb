# A client's reply on a task's discussion (from the portal or their agent): whoever is on the task
# hears, or the people who take requests on when nobody is yet.
class Notifier::ClientReplyNotifier < Notifier
  alias note source

  private
    def recipients = note.discussion? && note.from_client? ? note.subject.team_watchers(note) : []
    def creator = note.author
end
