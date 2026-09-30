class Mention::CreateJob < ApplicationJob
  def perform(record, mentioner:)
    Current.set(session: mentioner && Session.new(user: mentioner)) do
      record.create_mentions(mentioner: mentioner)
    end
  end
end
