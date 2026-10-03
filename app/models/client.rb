class Client < ApplicationRecord
  include Eventful, Noted, Searchable, Documentable, CustomFields

  STATUSES = %w[active dormant former].freeze

  # Restrictions first, so a client with agreed work is refused before anything is destroyed.
  has_many :engagements, dependent: :restrict_with_error
  has_many :contacts, dependent: :destroy
  has_many :commitments, dependent: :destroy
  has_many :requests, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :time_zone, inclusion: { in: ->(_) { ActiveSupport::TimeZone.all.map(&:name) }, message: "isn’t a time zone we know" }, allow_nil: true

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

  # Runs the block with times shown in the client's zone: its portal, approval pages and emails.
  def in_time_zone(&) = Time.use_zone(zone, &)

  def approvers = contacts.where(can_approve: true, archived_at: nil)

  def to_param = id.to_s

  def search_title = name
  def search_content = nil
  def search_client_id = id

  ActiveSupport.run_load_hooks(:runwell_client, self)
end
