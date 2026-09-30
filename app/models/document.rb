# A file kept on a client, engagement, scope item, todo or request. Staff see them all; the
# client portal shows only the ones marked client_visible.
class Document < ApplicationRecord
  include Searchable

  belongs_to :documentable, polymorphic: true
  belongs_to :uploaded_by, class_name: "User", optional: true
  has_one_attached :file

  validates :file, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :client_visible, -> { where(client_visible: true) }

  delegate :filename, :byte_size, :content_type, to: :file

  # Whoever uploaded it, or anyone who may delete records.
  def deletable_by?(user) = uploaded_by == user || user.can?(:delete_records)

  def search_title = filename.to_s
  def search_content = nil
  def search_client_id = documentable.is_a?(Client) ? documentable.id : documentable.try(:client_id) || documentable.try(:client)&.id
end
