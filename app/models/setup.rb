# The first-run checklist (Settings > Setup): the few things a new install needs before Runwell is
# useful, each checked off by what exists rather than by ticking. Owners land on it from the gear
# until the required steps are done.
class Setup
  Step = Data.define(:key, :title, :text, :done, :optional, :path)

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def complete? = required.all?(&:done)

  def steps
    @steps ||= [
      step(:address, "Set Runwell’s address", "Where your team and #{term(:client, count: 2).downcase} open it. Every link Runwell emails points there.",
        done: Runwell.host_set?, path: routes.settings_address_path),
      step(:time_zone, "Choose your time zone", "Times on your pages and in emails show in it.",
        done: Setting.time_zone_set?, path: routes.settings_address_path(anchor: "time_zone")),
      step(:mail, "Make sure email goes out", "Sign-in links, invitations and notifications are emails: give Runwell a mail server (or switch on a mail plugin) and send a test.",
        done: Setting.current.test_email["sent_at"].present?, path: routes.settings_email_path(tab: "server")),
      step(:client, "Add your first #{term(:client).downcase}", "Who you work for.",
        done: Client.exists?, path: routes.new_client_path),
      step(:team, "Invite your team", "Everyone else joins by an emailed link.",
        done: User.active.people.count > 1 || Invitation.pending.exists?, optional: true, path: routes.users_path),
      step(:names, "Check the words Runwell uses", "Call clients, #{term(:engagement, count: 2).downcase} and work whatever your business calls them.",
        done: Setting.current.terminology.present?, optional: true, path: routes.settings_names_path),
      step(:engagement, "Start your first #{term(:engagement).downcase}", "Something you run for a #{term(:client).downcase}, in #{term(:scope_item, count: 2).downcase} if it has parts.",
        done: Engagement.exists?, path: routes.new_engagement_path),
      step(:work, "Add the first #{term(:work).downcase}", "What needs doing, with who's on it and when it's due.",
        done: Todo.exists?, path: first_engagement_path),
      step(:requests_by_email, "Take requests by email", "#{term(:client, count: 2)} email an address and each message becomes a request: work for someone to take on.",
        done: Setting.current.requests_email.present? && Setting.inbound_ingress.present?, optional: true, path: routes.settings_email_path(tab: "receiving"))
    ]
  end

  def done_count = steps.count(&:done)

  private
    def required = steps.reject(&:optional)

    def step(key, title, text, done:, path:, optional: false) = Step.new(key:, title:, text:, done:, optional:, path:)

    def term(key, count: 1) = Setting.current.term(key, count: count)

    def routes = Rails.application.routes.url_helpers

    def first_engagement_path
      engagement = Engagement.open.order(:created_at).first
      engagement ? routes.engagement_path(engagement, tab: "work") : routes.engagements_path
    end
end
