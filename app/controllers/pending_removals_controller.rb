# Undo, from a removal's toast (PendingRemoval): within the window the records stay, and the page
# comes back with them on it; after it, they're gone and it says so.
class PendingRemovalsController < ApplicationController
  allow_staff
  agent_exempt :destroy, reason: "the Undo button on a removal's toast; agents remove at once and have nothing to undo"

  def destroy
    put_back = PendingRemoval.undo(params[:batch])
    notice, alert = put_back.positive? ? [ "Put back.", nil ] : [ nil, "Too late to undo: it’s gone." ]

    if request.format.turbo_stream?
      render turbo_stream: [ turbo_stream_flash(notice: notice, alert: alert), (turbo_stream.refresh(request_id: nil) if notice) ].compact
    else
      redirect_back fallback_location: tasks_path, notice: notice, alert: alert
    end
  end
end
