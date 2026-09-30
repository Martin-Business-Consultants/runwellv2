# A record whose rich text can @mention people. Mentions are Action Text attachments that
# Lexxy writes into the HTML; each model says which of its columns hold that HTML.
module Mentions
  extend ActiveSupport::Concern

  included do
    has_many :mentions, as: :source, dependent: :destroy
    has_many :mentionees, through: :mentions
    after_save_commit :create_mentions_later, if: :mentionable_content_changed?
  end

  class_methods do
    def mentionable_fields(*fields)
      define_method(:mentionable_fields) { fields }
    end
  end

  def create_mentions(mentioner: Current.user)
    scan_mentionees.each do |mentionee|
      mentionee.mentioned_by mentioner, at: self
    end
  end

  def mentionable_content
    mentionable_fields.filter_map { ActionText::Content.new(public_send(it).to_s).to_plain_text.presence }.join(" ")
  end

  def scan_mentionees
    mentionees_from_attachments & User.active.people
  end

  private
    def mentionees_from_attachments
      mentionable_fields.flat_map { ActionText::Content.new(public_send(it).to_s).attachables }.grep(User).uniq
    end

    def mentionable_content_changed?
      mentionable_fields.any? { saved_change_to_attribute?(it) }
    end

    def create_mentions_later
      Mention::CreateJob.perform_later(self, mentioner: Current.user)
    end
end
