class Client < ApplicationRecord
  include Eventful, Noted, Searchable, Documentable, CustomFields
  include LiveRefreshes, RecordsCreation, TextFilterable

  filters_text_on "clients.name", "(SELECT group_concat(users.name || ' ' || COALESCE(users.email_address, ''), ' ') FROM users WHERE users.client_id = clients.id)"

  # Any status moves to any other. Every change records client.status (from, to), first; setting it
  # dormant or former then sunsets its open work and tasks (Client::Sunset).
  STATUSES = %w[active dormant former].freeze

  # Restrictions first, so a client with agreed work is refused before anything is destroyed.
  has_many :works, dependent: :restrict_with_error
  # Its work, on its work or straight on it. A client with work can't be deleted, so
  # only work straight on it goes with it. Before its contacts, whose notes on them would hold them.
  has_many :tasks, dependent: :destroy
  has_many :contacts, dependent: :destroy
  # After the restriction above, so a client with work is refused before anything is touched.
  before_destroy :clear_legacy_rows!

  validates :name, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  # Before Sunset, whose callback follows, so the change comes first in its history.
  after_update :record_status_change, if: :saved_change_to_status?
  include Sunset

  validates :time_zone, inclusion: { in: ->(_) { ActiveSupport::TimeZone.all.map(&:name) + TZInfo::Timezone.all_identifiers }, message: "isn’t a time zone we know" }, allow_nil: true

  # A Rails zone name ("Pacific Time (US & Canada)"); an IANA one ("America/Los_Angeles") is
  # accepted and stored as its Rails name. Blank means the install's own zone.
  normalizes :time_zone, with: ->(value) { value.presence && (ActiveSupport::TimeZone::MAPPING.key(value) || value) }

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(status: "active") }

  # The clients list's status filter, each choice with how many it holds.
  def self.filter_options
    counts = group(:status).count
    STATUSES.map { [ "#{it.humanize} (#{counts.fetch(it, 0)})", it ] } + [ [ "All (#{counts.values.sum})", "all" ] ]
  end

  # Where the client is: its own zone, or the install's (Setting.zone) when it has none.
  def zone = time_zone ? ActiveSupport::TimeZone[time_zone] : Setting.zone
  def own_time_zone? = time_zone.present? && zone.name != Setting.zone.name

  # Runs the block with times shown in the client's zone: its portal, its client-facing pages and emails.
  def in_time_zone(&) = Time.use_zone(zone, &)

  def approvers = contacts.active.where(can_approve: true)

  # Every document shared with this client, newest first: on the client itself, on its work, its
  # work's sections, and the tasks it can see (on its work or straight on it). The portal's Documents.
  def client_documents
    works_ids = works.select(:id)
    shared_tasks = Task.client_visible.where(client_id: id).select(:id)
    Document.client_visible.where(documentable: self)
      .or(Document.client_visible.where(documentable_type: "Work", documentable_id: works_ids))
      .or(Document.client_visible.where(documentable_type: "ScopeItem", documentable_id: ScopeItem.where(work_id: works_ids).select(:id)))
      .or(Document.client_visible.where(documentable_type: "Task", documentable_id: shared_tasks))
      .recent.includes(:documentable, file_attachment: :blob)
  end

  def to_param = id.to_s

  def search_title = name
  def search_content = nil
  def search_client_id = id

  ActiveSupport.run_load_hooks(:runwell_client, self)

  private
    # Rows from before contacts were users and requests were tasks (the contacts, requests and
    # commitments tables, and what pointed at those contacts) still name this client: their foreign
    # keys would refuse deleting it, so they go first. Nothing reads them.
    def clear_legacy_rows!
      db = self.class.connection
      if db.table_exists?(:contacts)
        contacts = db.select_values("SELECT id FROM contacts WHERE client_id = #{id.to_i}").map(&:to_i)
        if contacts.any?
          list = contacts.join(",")
          %w[access_tokens oauth_grants].each do |table|
            db.execute("UPDATE #{table} SET contact_id = NULL WHERE contact_id IN (#{list})") if db.column_exists?(table, :contact_id)
          end
          %w[portal_sessions approval_links approvals].each do |table|
            db.execute("DELETE FROM #{table} WHERE contact_id IN (#{list})") if db.table_exists?(table)
          end
          %w[requests commitments].each do |table|
            db.execute("UPDATE #{table} SET contact_id = NULL WHERE contact_id IN (#{list})") if db.table_exists?(table)
          end
        end
      end
      db.execute("DELETE FROM requests WHERE client_id = #{id.to_i}") if db.table_exists?(:requests)
      db.execute("DELETE FROM commitments WHERE client_id = #{id.to_i}") if db.table_exists?(:commitments)
      db.execute("DELETE FROM contacts WHERE client_id = #{id.to_i}") if db.table_exists?(:contacts)
    end

    def live_streams = [ self, :clients ]

    def record_status_change
      record_event!("client.status", payload: { from: status_before_last_save, to: status })
    end
end
