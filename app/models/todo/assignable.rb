# Who's on a piece of work: its owner (the lead) and anyone else, Fizzy's assignments. Everyone on
# it, the lead too, has an assignment, so "my work" is work anyone gave me a part in. Setting the
# owner directly (a form, a bulk change, an agent, a plugin) replaces the lead and keeps the rest.
module Todo::Assignable
  extend ActiveSupport::Concern

  included do
    has_many :assignments, -> { order(:created_at, :id) }, dependent: :delete_all, inverse_of: :todo
    has_many :assignees, through: :assignments, source: :user

    scope :assigned_to, ->(users) { where(id: Assignment.where(user: users).select(:todo_id)) }

    # The rest of the team on it, beside the lead (update_work's other_owner_ids, the edit form).
    attr_reader :other_owner_ids

    after_save :follow_lead, if: -> { saved_change_to_owner_id? && !@leading }
    after_save :apply_other_owners, unless: -> { @other_owner_ids.nil? }
  end

  # Everyone on it, the lead first. Reads loaded assignments (preload `assignments: :user`).
  def owners
    people = assignments.map(&:user)
    people = [ owner, *people ] if owner && people.none? { it.id == owner_id }
    people.sort_by { it.id == owner_id ? 0 : 1 }
  end

  def other_owners = owners.reject { it.id == owner_id }

  def assigned_to?(user) = owner_id == user.id || assignments.any? { it.user_id == user.id }

  def other_owner_ids=(ids)
    @other_owner_ids = Array(ids).compact_blank.map(&:to_i)
  end

  # The picker's click: on if they're off it, off if they're on.
  def toggle_assignment!(user, by: Current.user)
    assigned_to?(user) ? unassign!(user) : assign!(user, by: by)
  end

  # Puts someone on it; the first one on leads.
  def assign!(user, by: Current.user)
    transaction do
      assignments.find_or_create_by!(user: user) { it.assigner = by&.person }
      lead!(user) if owner_id.nil?
    end
  end

  # Takes someone off it; when that was the lead, whoever came on next leads, or nobody.
  def unassign!(user)
    transaction do
      assignments.where(user: user).delete_all
      assignments.reset
      lead!(assignments.first&.user) if owner_id == user.id
    end
  end

  private
    def lead!(user)
      @leading = true
      update!(owner: user)
    ensure
      @leading = false
    end

    def follow_lead
      before, now = saved_change_to_owner_id
      assignments.where(user_id: before).delete_all if before
      assignments.find_or_create_by!(user_id: now) { it.assigner_id = Current.user&.person&.id } if now
      assignments.reset
      lead!(assignments.first.user) if now.nil? && @other_owner_ids.nil? && assignments.any?
    end

    # Everyone else on it becomes exactly these (people only); with no lead, the first leads.
    def apply_other_owners
      ids, @other_owner_ids = @other_owner_ids, nil
      people = User.active.people.where(id: ids).ids.sort_by { ids.index(it) }
      lead!(User.find(people.first)) if owner_id.nil? && people.any?

      wanted = ([ owner_id ] + people).compact.uniq
      assignments.where.not(user_id: wanted).delete_all
      (wanted - assignments.pluck(:user_id)).each { assignments.create!(user_id: it, assigner_id: Current.user&.person&.id) }
      assignments.reset
    end
end
