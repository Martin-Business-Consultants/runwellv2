# A file kept on a client, work, scope item, task or request. Staff see them all; the
# client portal shows only the ones marked client_visible.
class Document < ApplicationRecord
  include LiveRefreshes
  include Searchable

  belongs_to :documentable, polymorphic: true
  belongs_to :uploaded_by, class_name: "User", optional: true
  has_one_attached :file

  # The largest file one document may hold, RUNWELL_MAX_UPLOAD_MB (100 MB unless set): Cloudflare's
  # proxy refuses a bigger request on its Free and Pro plans. An install not behind it may raise it.
  MAX_SIZE = ENV.fetch("RUNWELL_MAX_UPLOAD_MB", 100).to_i.megabytes

  validates :file, presence: true
  validate :file_within_limit

  scope :recent, -> { order(created_at: :desc) }
  # What a list of them reads per row: its file and who uploaded it.
  scope :preloaded, -> { includes(:uploaded_by, file_attachment: :blob) }
  scope :client_visible, -> { where(client_visible: true) }

  delegate :filename, :byte_size, :content_type, to: :file

  # A file the team shares with a client is emailed to their people, a few minutes on so several
  # shared together go as one (SharedDocumentsJob). Not the client's own uploads, nor an import.
  after_commit :tell_client_later, on: %i[create update], if: -> { saved_change_to_client_visible? && client_visible? }

  # The client it belongs to, through whatever it's on.
  def client = Client.find_by(id: search_client_id)

  # Whoever uploaded it (or whose agent did), or anyone who may delete records.
  def deletable_by?(user)
    return false unless user

    person_id = user.person.id
    uploaded_by_id == person_id || (uploaded_by_id.present? && uploaded_by&.agent_owner_id == person_id) || user.can?(:delete_records)
  end

  def search_title = filename.to_s
  def search_content = nil
  def search_client_id = documentable.is_a?(Client) ? documentable.id : documentable.try(:client_id) || documentable.try(:client)&.id

  ActiveSupport.run_load_hooks(:runwell_document, self)

  private
    def file_within_limit
      errors.add(:file, "is over the #{ActiveSupport::NumberHelper.number_to_human_size(MAX_SIZE)} limit") if file.attached? && file.byte_size > MAX_SIZE
    end

    def live_streams = [ documentable, documentable.try(:work), documentable.try(:client) ]

    def tell_client_later
      SharedDocumentsJob.set(wait: SharedDocumentsJob::QUIET).perform_later(self) unless Current.source == "import" || uploaded_by&.client?
    end
end
