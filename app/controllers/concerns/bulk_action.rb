# One action on many records at once, from a table's selection (layouts/shared/bulk_bar) or an
# agent: each record goes through the same model verb and rules as doing it alone, one at a time,
# so permissions, validations and events are unchanged. A record the action doesn't apply to (sent
# already, not open, has engagements) is skipped and named in the result rather than failing the rest.
#
#   apply_to_each(records, done: "Moved %{count} to done") { |todo| todo.update(status: "done") || todo.errors.full_messages.to_sentence }
#
# The block answers true when it worked, or the reason it didn't.
module BulkAction
  extend ActiveSupport::Concern

  MAX = 500

  private
    def selected(scope)
      ids = Array(params[:ids]).flat_map { it.to_s.split(",") }.map(&:to_i).select(&:positive?).uniq.first(MAX)
      scope.where(id: ids).to_a
    end

    def apply_to_each(records, done:, fallback:)
      return redirect_back(fallback_location: fallback, alert: "Select at least one first.") if records.empty?

      skipped = []
      count = records.count do |record|
        result = begin
          yield(record)
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed, ArgumentError => error
          error.message
        end
        next true if result == true

        skipped << "#{bulk_label(record)} (#{result.presence || "it couldn’t be changed"})"
        false
      end

      message = [ (format(done, count: count) if count.positive?), ("Skipped #{skipped.size}: #{skipped.first(5).join("; ")}#{" and #{skipped.size - 5} more" if skipped.size > 5}." if skipped.any?) ].compact.join(". ")
      flash_key = count.positive? ? :notice : :alert
      redirect_back fallback_location: fallback, flash_key => message.end_with?(".") ? message : "#{message}."
    end

    def bulk_label(record)
      name = record.try(:ref) || record.try(:name) || record.try(:title) || record.try(:subject) || record.try(:description).to_s.truncate(40)
      "“#{name}”"
    end

    def counted(count, noun) = helpers.pluralize(count, noun)
end
