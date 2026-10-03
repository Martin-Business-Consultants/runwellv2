# The address clients email requests to (RequestsMailbox), and that replies come back to.
class AddRequestsEmailToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :requests_email, :string
  end
end
