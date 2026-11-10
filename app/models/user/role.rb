# What a person may do. Three fixed staff roles; each permission names the roles that have it.
# Plugins add their own (Runwell::Plugins.permission). There is no permission builder:
# an install that needs finer control adds a plugin. A fourth, client, is someone at a client
# (Contact): no permissions, no staff sign-in, only the portal, and never in staff pickers.
module User::Role
  extend ActiveSupport::Concern

  ROLES = %w[owner manager member].freeze
  CLIENT = "client"

  ROLE_DESCRIPTIONS = {
    "owner" => "Everything, including settings, plugins and people",
    "manager" => "Closes work and deletes records",
    "member" => "Does the work: takes it on, notes and documents"
  }.freeze

  PERMISSIONS = {
    manage_settings: { name: "Change settings and plugins", roles: %w[owner] },
    manage_people: { name: "Invite people and change their roles", roles: %w[owner] },
    manage_intake: { name: "Set who hears what comes into Intake, and when", roles: %w[owner manager] },
    close_works: { name: "Close work", roles: %w[owner manager] },
    erase_works: { name: "Delete closed work permanently, with its tasks and history", roles: %w[owner] },
    delete_records: { name: "Delete records", roles: %w[owner manager] }
  }.freeze

  included do
    validates :role, inclusion: { in: ROLES + [ CLIENT ] }
    validate :keeps_an_owner, on: :update

    scope :active, -> { where(deactivated_at: nil) }
    scope :deactivated, -> { where.not(deactivated_at: nil) }
    scope :owners, -> { where(role: "owner") }
    scope :ordered, -> { order(:name) }
    scope :staff, -> { where.not(role: CLIENT) }
    scope :clients, -> { where(role: CLIENT) }
    # Who hears that a request came in, or that a client wrote on a task nobody has taken on:
    # the people who can hand it to someone.
    scope :request_watchers, -> { people.active.where(role: %w[owner manager]) }
  end

  class_methods do
    # The core's permissions and those of plugins that are on.
    def permissions = PERMISSIONS.merge(Runwell::Plugins.enabled_permissions)
  end

  def owner? = role == "owner"
  def client? = role == CLIENT
  def staff? = !client?
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
