# Builds an Export's .zip away from the request, and clears out ones older than a week.
class ExportJob < ApplicationJob
  def perform(export)
    Export.expire_old!
    export.build!
  end
end
