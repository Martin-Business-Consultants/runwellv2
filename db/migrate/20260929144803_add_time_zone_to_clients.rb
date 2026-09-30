class AddTimeZoneToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :time_zone, :string
  end
end
