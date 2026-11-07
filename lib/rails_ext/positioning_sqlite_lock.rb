# The positioning gem locks a list before renumbering it by loading every row in it
# (SELECT … FOR UPDATE). That's for databases that lock rows; SQLite ignores FOR UPDATE and lets
# one write happen at a time anyway, so on SQLite the load bought nothing and cost a read of
# every task in a status, twice, on each status change (the Tasks board's lists span all
# work: thousands of done tasks on a large install). Skip it there.
module PositioningSqliteLock
  private
    def lock_positioning_scope!
      super unless @positioned.class.connection.adapter_name == "SQLite"
    end
end

Rails.application.config.to_prepare { Positioning::Mechanisms.prepend(PositioningSqliteLock) }
