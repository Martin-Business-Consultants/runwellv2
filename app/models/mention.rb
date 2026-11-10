class Mention < ApplicationRecord
  include Notifiable

  belongs_to :source, polymorphic: true
  belongs_to :mentioner, class_name: "User"
  belongs_to :mentionee, class_name: "User", inverse_of: :mentions

  def self_mention?
    mentioner == mentionee
  end

  def notifiable_target
    source
  end

  def notification_title = "#{mentioner.first_name} mentioned you"
  def notification_excerpt = source.mentionable_content.to_s
end
