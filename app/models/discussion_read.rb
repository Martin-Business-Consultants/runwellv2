# How far someone at a client has read a task's discussion in the portal (Task::Discussion): one row
# per contact and task, moved on when they open the task or reply.
class DiscussionRead < ApplicationRecord
  belongs_to :user
  belongs_to :task
end
