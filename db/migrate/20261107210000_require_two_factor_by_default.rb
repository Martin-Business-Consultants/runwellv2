# Two-factor sign-in is required of everyone on a new install (Settings > Your account turns it
# off). An existing install keeps the choice it made.
class RequireTwoFactorByDefault < ActiveRecord::Migration[8.1]
  def change
    change_column_default :settings, :require_two_factor, from: false, to: true
  end
end
