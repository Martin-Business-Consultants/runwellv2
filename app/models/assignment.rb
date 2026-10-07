# One person on a piece of work (Fizzy's). The work's owner is its lead; everyone on it, the lead
# too, has an assignment.
class Assignment < ApplicationRecord
  belongs_to :todo, inverse_of: :assignments
  belongs_to :user
  belongs_to :assigner, class_name: "User", optional: true

  validates :user_id, uniqueness: { scope: :todo_id }
end
