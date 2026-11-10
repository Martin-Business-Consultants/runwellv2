# A task's discussion with its client: the notes either side shared on it (Note.discussion), shown
# on the task in the portal. Here is who takes part, what each contact hasn't read yet, and what a
# client reads as its status.
module Task::Discussion
  extend ActiveSupport::Concern

  # What a client reads for a status: the team's five, less what's only the team's business.
  CLIENT_STATUSES = %w[received planned in_progress on_hold done].freeze

  included do
    has_many :discussion_reads, dependent: :delete_all

    after_update_commit :tell_asker_its_done, if: -> { saved_change_to_status? && status == "done" }
    after_update_commit :tell_asker_its_taken_on, if: -> { saved_change_to_owner_id? && owner_id_before_last_save.nil? && owner_id.present? }
  end

  class_methods do
    # The ids of a client's shared tasks holding something this contact hasn't read: a note shared
    # on it by anyone else, since they last opened it.
    def unread_discussion_ids(contact)
      Note.client_visible.where(subject_type: "Task", subject_id: client_visible.where(client_id: contact.client_id).select(:id))
        .where("notes.author_id IS NULL OR notes.author_id != ?", contact.id)
        .joins("LEFT JOIN discussion_reads ON discussion_reads.task_id = notes.subject_id AND discussion_reads.user_id = #{contact.id.to_i}")
        .where("discussion_reads.read_at IS NULL OR notes.occurred_at > discussion_reads.read_at")
        .distinct.pluck(:subject_id)
    end
  end

  # Asked for from outside (the portal, an email, their agent) or logged for someone at the client.
  def asked_for? = contact_id.present? || sender_email.present? || sender_name.present?

  # received: asked for and nobody has taken it on yet. in review reads as in progress (that check
  # is ours), blocked as on hold.
  def client_status
    return "received" if request? && asked_for?

    { "in_review" => "in_progress", "blocked" => "on_hold" }.fetch(status, status)
  end

  def client_status_label = client_status.humanize

  # Open and past its date, as a client sees it.
  def late? = due_on.present? && status != "done" && due_on < Date.current

  def discussion_read_by!(contact)
    read = discussion_reads.find_or_initialize_by(user_id: contact.id)
    read.update!(read_at: Time.current)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  # Who at the client a message on it is usually for: whoever asked for it and anyone who wrote on
  # it, or, when that's nobody, everyone there who uses the portal. Only those who can sign in and
  # want mail (Notice.reachable_contacts).
  def discussion_contacts
    return [] unless client

    ids = [ contact_id, *notes.client_visible.where(author_id: Contact.where(client_id: client_id).select(:id)).distinct.pluck(:author_id) ].compact
    reachable = Notice.reachable_contacts(client)
    reachable.select { it.id.in?(ids) }.presence || reachable
  end

  # Who at the client is emailed a message on it (Notice: a plugin may choose among them).
  def reply_contacts(note) = Notice.contacts("reply", client: client, record: note, usual: discussion_contacts)

  # Who on the team hears about what a client sends on it: usually whoever is on the task, else the
  # people who take requests on (User.request_watchers).
  def team_watchers(note = nil)
    people = owners.select { it.active? && !it.agent? }
    Notice.people("reply", client: client, record: note || self, usual: people.presence || User.request_watchers.to_a)
  end

  private
    # A minute on, so an Undo in the meantime sends nothing (PortalMailer#done checks again). Not
    # when something other than a person finished it (a client's sunset), nor from an import.
    def tell_asker_its_done
      return if status_reason.present? || Current.source == "import" || !client_visible? || !asked_for?

      Notice.contacts("done", client: client, record: self, usual: [ contact ].compact).each do
        PortalMailer.with(task: self, contact: it).done.deliver_later(wait: 1.minute)
      end
    end

    # Someone took on what they asked for: the first person put on it. A minute on too, checked
    # again when it's sent (PortalMailer#taken_on).
    def tell_asker_its_taken_on
      return if Current.source == "import" || !client_visible? || !asked_for? || status == "done"

      Notice.contacts("taken_on", client: client, record: self, usual: [ contact ].compact).each do
        PortalMailer.with(task: self, contact: it).taken_on.deliver_later(wait: 1.minute)
      end
    end
end
