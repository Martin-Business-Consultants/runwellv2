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
end
