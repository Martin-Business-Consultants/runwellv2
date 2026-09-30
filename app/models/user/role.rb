# What a person may do. Three fixed roles; each permission names the roles that have it.
# Plugins add their own (Runwell::Plugins.permission). There is no permission builder:
# an install that needs finer control adds a plugin.
module User::Role
  extend ActiveSupport::Concern

  ROLES = %w[owner manager member].freeze

  ROLE_DESCRIPTIONS = {
    "owner" => "Everything, including settings, plugins and people",
    "manager" => "Sends agreements, records decisions, triages, closes and deletes",
    "member" => "Does the work: todos, notes, documents and commitments"
  }.freeze

  PERMISSIONS = {
    manage_settings: { name: "Change settings and plugins", roles: %w[owner] },
    manage_people: { name: "Invite people and change their roles", roles: %w[owner] },
    send_agreements: { name: "Send agreements and record client decisions", roles: %w[owner manager] },
    close_engagements: { name: "Close engagements", roles: %w[owner manager] },
    triage_requests: { name: "Triage requests", roles: %w[owner manager] },
    delete_records: { name: "Delete records", roles: %w[owner manager] }
  }.freeze

  included do
    validates :role, inclusion: { in: ROLES }
    validate :keeps_an_owner, on: :update

    scope :active, -> { where(deactivated_at: nil) }
    scope :deactivated, -> { where.not(deactivated_at: nil) }
    scope :owners, -> { where(role: "owner") }
    scope :ordered, -> { order(:name) }
  end

  class_methods do
    # The core's permissions and those of plugins that are on.
    def permissions = PERMISSIONS.merge(Runwell::Plugins.enabled_permissions)
  end

  def owner? = role == "owner"
  # An agent is active only while its person is.
  def active? = deactivated_at.nil? && (!agent? || agent_owner&.active?)
  def deactivated? = !active?

  # A permission from a plugin that is off is simply not held.
  def can?(permission)
    return agent_owner.can?(permission) if agent?

    rule = User.permissions[permission.to_sym]
    return false if rule.nil? && Runwell::Plugins.permissions.values.any? { it.key?(permission.to_sym) }
    raise ArgumentError, "Unknown permission: #{permission}" if rule.nil?

    active? && rule[:roles].include?(role)
  end

  def deactivate!
    transaction do
      update!(deactivated_at: Time.current)
      sessions.destroy_all
      access_tokens.live.find_each(&:revoke!)
      agent&.update!(deactivated_at: Time.current)
    end
  end

  def reactivate!
    transaction do
      update!(deactivated_at: nil)
      agent&.update!(deactivated_at: nil)
    end
  end

  private
    # Someone always runs the place: the last active owner can't step down or be deactivated.
    def keeps_an_owner
      losing_owner = (role_changed? && role_was == "owner") || (deactivated_at_changed? && deactivated_at.present? && owner?)
      if losing_owner && !agent? && User.active.people.owners.where.not(id: id).none?
        errors.add(:base, "Runwell needs an active owner. Make someone else an owner first.")
      end
    end
end
