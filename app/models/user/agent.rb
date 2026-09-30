# A person's agent: the user that apps they connect act as. Every access token (personal or
# OAuth) belongs to a person, but the requests it makes run as that person's agent, so notes,
# events and records say "Ted's agent" (and the app, "via Claude"). An agent has its person's
# permissions exactly, can't sign in with a password, stays out of pickers and mentions, and is
# deactivated with its person.
module User::Agent
  extend ActiveSupport::Concern

  included do
    belongs_to :agent_owner, class_name: "User", optional: true, inverse_of: :agent
    has_one :agent, class_name: "User", foreign_key: :agent_owner_id, inverse_of: :agent_owner, dependent: :restrict_with_error

    scope :people, -> { where(agent_owner_id: nil) }
    scope :agents, -> { where.not(agent_owner_id: nil) }

    validate :agent_owner_is_a_person, if: :agent?
    after_create_commit :create_agent_later, unless: :agent?
    after_update :sync_agent, if: -> { !agent? && agent && (saved_change_to_role? || saved_change_to_name?) }
  end

  def agent? = agent_owner_id.present?

  # Who this is on behalf of: the person, for a person or their agent.
  def person = agent? ? agent_owner : self

  # This person's agent, made the first time it's needed.
  def agent!
    raise ArgumentError, "an agent has no agent" if agent?

    agent || create_agent!(name: agent_name, email_address: agent_email_address, role: role, password: SecureRandom.base58(32))
  rescue ActiveRecord::RecordNotUnique
    reload.agent
  end

  private
    def agent_name = "#{name.presence || email_address.split("@").first}'s agent"

    # ted@brem.io → ted+agent@brem.io, or +agent2… if that's taken.
    def agent_email_address
      local, domain = email_address.split("@", 2)
      candidates = [ "#{local}+agent@#{domain}" ] + (2..20).map { "#{local}+agent#{it}@#{domain}" }
      candidates.find { !User.exists?(email_address: it) } or raise "no free agent address for #{email_address}"
    end

    def agent_owner_is_a_person
      errors.add(:agent_owner, "must be a person, not another agent") if agent_owner&.agent?
    end

    def create_agent_later = agent!

    def sync_agent
      agent.update!(role: role, name: agent_name)
    end
end
