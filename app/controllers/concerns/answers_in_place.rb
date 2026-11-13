# Answers for forms on the page you're on (AGENTS.md, Frontend). A form marks itself with
# `inline` (the field it saves, the section it adds to, the row it removes) and asks for a turbo
# stream; the action answers with streams that redraw what changed, and redirects for everyone
# else (agents, plain posts, the quick action tray).
#
# A record deleted from its table row: its trash button sends inline=row (once the confirm
# dialog says yes), and the answer removes that row (every row partial's <tr> is dom_id(record, :row)) and says so, with no
# reload; a refusal says why where you are.
module AnswersInPlace
  extend ActiveSupport::Concern

  private
    def inline?(form) = params[:inline] == form && request.format.turbo_stream?

    def row_removal? = inline?("row")

    # A form in the modal (an index's New, Add a contact): saved, the answer is a stream that closes
    # the modal and adds the new record where you are, rather than a page of its own.
    def from_modal? = turbo_frame_request_id == "modal" && request.format.turbo_stream?

    def remove_row(record, notice:, also: [])
      render turbo_stream: [ turbo_stream.remove(helpers.dom_id(record, :row)), *also, turbo_stream_flash(notice: notice) ]
    end

    # A notice whose toast offers Undo for a removal's window (PendingRemoval): runeui's toast,
    # whose action sends the request (TurboFlash, ui_flash_toasts after a redirect).
    def undo_notice(text, batch)
      { title: text, duration: PendingRemoval::WINDOW.in_milliseconds,
        action: { label: "Undo", url: pending_removal_path(batch), method: :delete } }
    end

    # Removed in the browser (a Turbo form, not an agent or a plain post): with Undo.
    def removing_with_undo? = request.format.turbo_stream? && !Current.agent?

    def refuse_in_place(alert)
      render turbo_stream: turbo_stream_flash(alert: alert), status: :unprocessable_entity
    end
end
