module User::Mentionable
  extend ActiveSupport::Concern

  included do
    include ActionText::Attachable

    has_many :mentions, dependent: :destroy, inverse_of: :mentionee, foreign_key: :mentionee_id

    # Need to set in the included block so that it overrides Action Text's
    def to_attachable_partial_path
      "users/attachable"
    end

    def to_editor_content_attachment_partial_path
      to_attachable_partial_path
    end

    def attachable_plain_text_representation(...)
      "@#{first_name.downcase}"
    end
  end

  def mentioned_by(mentioner, at:)
    mentions.find_or_create_by! source: at, mentioner: mentioner
  end

  def content_type
    "application/vnd.actiontext.mention"
  end
end
