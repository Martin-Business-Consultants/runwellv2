class AddCloseOutcomeToEngagements < ActiveRecord::Migration[8.1]
  def change
    add_column :engagements, :close_outcome, :string
  end
end
