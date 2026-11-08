class Client < ApplicationRecord
  include Eventful, Noted, Searchable, Documentable, CustomFields
  include LiveRefreshes, RecordsCreation
  include Sunset

  STATUSES = %w[active dormant former].freeze

  # Restrictions first, so a client with agreed work is refused before anything is destroyed.
  has_many :works, dependent: :restrict_with_error
  has_many :contacts, dependent: :destroy
  # Its work, on its work or straight on it. A client with work can't be deleted, so
  # only work straight on it goes with it.
  has_many :tasks, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
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
    def live_streams = [ self, :clients ]
end
