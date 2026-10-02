# A file kept on a client, engagement, scope item, todo or request. Staff see them all; the
# client portal shows only the ones marked client_visible.
class Document < ApplicationRecord
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
  scope :client_visible, -> { where(client_visible: true) }

  delegate :filename, :byte_size, :content_type, to: :file

  # Whoever uploaded it, or anyone who may delete records.
  def deletable_by?(user) = uploaded_by == user || user.can?(:delete_records)

  def search_title = filename.to_s
  def search_content = nil
  def search_client_id = documentable.is_a?(Client) ? documentable.id : documentable.try(:client_id) || documentable.try(:client)&.id

  private
    def file_within_limit
      errors.add(:file, "is over the #{ActiveSupport::NumberHelper.number_to_human_size(MAX_SIZE)} limit") if file.attached? && file.byte_size > MAX_SIZE
    end
end
