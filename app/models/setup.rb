# The first-run checklist on home: the few things a new install needs before Runwell is useful,
# each checked off by what exists rather than by ticking. Shown to the owner until the required
# steps are done or they dismiss it (Setting#setup_dismissed_at).
class Setup
  Step = Data.define(:key, :title, :text, :done, :optional, :path)

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def show? = user.can?(:manage_settings) && Setting.current.setup_dismissed_at.nil? && !required.all?(&:done)

  def steps
    @steps ||= [
      step(:client, "Add your first #{term(:client).downcase}", "Who you work for.",
        done: Client.exists?, path: routes.new_client_path),
      step(:approver, "Add a contact who can approve", "Agreements go to them to approve or ask for changes.",
        done: Contact.active.where(can_approve: true).exists?, path: first_client_path),
      step(:team, "Invite your team", "Everyone else joins by an emailed link.",
        done: User.active.people.count > 1 || Invitation.pending.exists?, optional: true, path: routes.settings_people_path),
      step(:names, "Check the words Runwell uses", "Call clients, #{term(:engagement, count: 2).downcase} and work whatever your business calls them.",
        done: Setting.current.terminology.present?, optional: true, path: routes.settings_names_path),
      step(:engagement, "Draft your first #{term(:engagement).downcase}", "What you agreed to do, as scope items.",
        done: Engagement.exists?, path: routes.new_engagement_path),
      step(:send, "Send an agreement", "The client approves it from a link, and approving creates the work.",
        done: AgreementVersion.where.not(sent_at: nil).exists?, path: first_draft_path)
    ]
  end

  def done_count = steps.count(&:done)

  private
    def required = steps.reject(&:optional)

    def step(key, title, text, done:, path:, optional: false) = Step.new(key:, title:, text:, done:, optional:, path:)

    def term(key, count: 1) = Setting.current.term(key, count: count)

    def routes = Rails.application.routes.url_helpers

    def first_client_path
      client = Client.order(:created_at).first
      client ? routes.client_path(client) : routes.new_client_path
    end

    def first_draft_path
      engagement = Engagement.open.where.not(id: AgreementVersion.where.not(sent_at: nil).select(:engagement_id)).order(:created_at).first
      engagement ? routes.engagement_path(engagement) : routes.engagements_path(state: "draft")
    end
end
