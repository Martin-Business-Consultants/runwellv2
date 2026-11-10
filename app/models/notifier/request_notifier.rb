# A request from outside (the portal, an email, a client's agent): the people who take requests on
# hear it came in (User.request_watchers). Who asked is the creator, when we have them on file.
class Notifier::RequestNotifier < Notifier
  alias task source

  private
    def recipients = Notice.people("request", client: task.client, record: task, usual: User.request_watchers.to_a)
    def creator = task.contact
end
