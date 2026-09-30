class ApprovalLink < ApplicationRecord
  belongs_to :agreement_version
  belongs_to :contact

  scope :live, -> { where("expires_at > ?", Time.current) }

  def expired? = expires_at <= Time.current
  def usable? = !expired? && agreement_version.awaiting_decision?
  def opened!
    update_column(:opened_at, Time.current) if opened_at.nil?
  end
  def to_param = token
end
