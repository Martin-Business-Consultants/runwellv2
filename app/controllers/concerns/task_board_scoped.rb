# The Tasks board's filters, shared by the board, its column frames and its drops.
module TaskBoardScoped
  extend ActiveSupport::Concern

  included do
    helper_method :board_tasks
  end

  private

  # A move the task refuses (a rule a plugin adds, say): the page refreshes, so the card goes
  # back where it was, and says why.
  def refuse_move(error)
    flash[:alert] = error.record.errors.full_messages.to_sentence
    render turbo_stream: turbo_stream.refresh(request_id: nil)
  end

  # Your own tasks unless the filter says otherwise, as on the page (TasksController#index), and
  # the page filter's words (?q=).
  def board_tasks
    Task.filtered(owner: owner_filter_for(params[:owner].presence || "me"), work: params[:work].presence || "all").filter_text(params[:q])
  end

  # The owner filter as Task.filtered takes it: "any", or an owner (User.owner_id_for; "me" is the
  # person, for their agent too the person it acts for). A name that matches several people takes
  # the best match, and one that matches no one shows nothing, since a filter never errors.
  def owner_filter_for(owner)
    return "any" if owner == "any"

    User.owner_id_for(owner, me: current_user.person)
  rescue Agent::Resolver::Ambiguous => ambiguous
    ambiguous.candidates.first&.id
  rescue Agent::Resolver::Missing
    0
  end
end
