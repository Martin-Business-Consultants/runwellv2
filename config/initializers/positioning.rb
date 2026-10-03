# The positioning gem locks a list before renumbering it by loading every row in it
# (SELECT … FOR UPDATE). That's for databases that lock rows; SQLite ignores FOR UPDATE and lets
# one write happen at a time anyway, so on SQLite the load bought nothing and cost a read of
# every todo in a status, twice, on each status change (the Work board's lists span every
# engagement: thousands of done todos on a large install). Skip it there.
Rails.application.config.to_prepare do
  Positioning::Mechanisms.prepend(Module.new do
    private
      def lock_positioning_scope!
        super unless @positioned.class.connection.adapter_name == "SQLite"
      end
  end)
end
