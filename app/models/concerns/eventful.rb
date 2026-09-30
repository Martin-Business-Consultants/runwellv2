# A record that keeps an append-only history of what happened to it.
module Eventful
  extend ActiveSupport::Concern

  included do
    has_many :events, as: :subject, dependent: :destroy
  end

  # Every write of consequence goes through here so it carries an actor and a source. Done by
  # an agent, it keeps the person (actor) and names the app acting for them (actor_label).
  def record_event!(kind, actor: Current.user, source: Current.source, payload: {}, occurred_at: Time.current, actor_label: Current.access_token&.name)
    events.create!(kind: kind, payload: payload, actor_user: actor, actor: actor_label,
                   source: source || "app", occurred_at: occurred_at)
  end
end
