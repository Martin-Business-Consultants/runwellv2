# What a person may do. Three fixed roles; each permission names the roles that have it.
# Plugins add their own (Runwell::Plugins.permission). There is no permission builder:
# an install that needs finer control adds a plugin.
module User::Role
  extend ActiveSupport::Concern

  ROLES = %w[owner manager member].freeze

  ROLE_DESCRIPTIONS = {
    "owner" => "Everything, including settings, plugins and people",
    "manager" => "Closes engagements and deletes records",
    "member" => "Does the work: takes it on, notes and documents"
  }.freeze

  PERMISSIONS = {
    manage_settings: { name: "Change settings and plugins", roles: %w[owner] },
    manage_people: { name: "Invite people and change their roles", roles: %w[owner] },
    close_engagements: { name: "Close engagements", roles: %w[owner manager] },
    erase_engagements: { name: "Delete closed engagements permanently, with their work and history", roles: %w[owner] },
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
      record_event!("user.deactivated")
      sessions.destroy_all
      access_tokens.live.find_each(&:revoke!)
      agent&.update!(deactivated_at: Time.current)
    end
  end

  def reactivate!
    transaction do
      update!(deactivated_at: nil)
      record_event!("user.reactivated")
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
