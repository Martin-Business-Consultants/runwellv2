# Check now and the test email run as jobs: the page shows they're under way from the time
# they were asked for, and how they went once the job has run.
class AddBackgroundCheckResultsToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :release_check_requested_at, :datetime
    add_column :settings, :release_check_error, :string
    add_column :settings, :test_email, :json, default: {}, null: false
  end
end
