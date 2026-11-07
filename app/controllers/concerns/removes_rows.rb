# A record deleted from its table row: the table's one delete dialog sends inline=row, and the
# answer removes that row (every row partial's <tr> is dom_id(record, :row)) and says so, with no
# reload; a refusal says why where you are. Anywhere else, the action redirects as usual.
module RemovesRows
  extend ActiveSupport::Concern

  private
    def row_removal? = params[:inline] == "row" && request.format.turbo_stream?

    def remove_row(record, notice:, also: [])
      render turbo_stream: [ turbo_stream.remove(helpers.dom_id(record, :row)), *also, turbo_stream_flash(notice: notice) ]
    end

    def refuse_in_place(alert)
      render turbo_stream: turbo_stream_flash(alert: alert), status: :unprocessable_entity
    end
end
