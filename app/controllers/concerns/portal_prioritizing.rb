# A client putting one of their things in order of priority (ClientPrioritized): a drop in the
# portal, which already shows the new order, gets an empty answer; anyone else (their agent, a plain
# form) is sent back with a notice.
module PortalPrioritizing
  extend ActiveSupport::Concern

  private
    # refresh: whether the page redraws after a drop (morphing, scroll kept), when other things on it
    # follow the order (a work's tasks are grouped by its sections).
    def prioritize(record, before, refresh: false)
      record.prioritize!(before: before, by: current_contact)
      if request.format.turbo_stream?
        refresh ? render(turbo_stream: turbo_stream.refresh(request_id: nil)) : head(:no_content)
      else
        redirect_back fallback_location: portal_root_path, notice: "#{record.priority_name} is now #{record.client_rank_label} on your list."
      end
    end
end
