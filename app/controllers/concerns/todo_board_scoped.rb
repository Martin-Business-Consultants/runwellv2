# The Work board's filters, shared by the board, its column frames and its drops.
module TodoBoardScoped
  extend ActiveSupport::Concern

  private

  # A move the todo refuses (a rule a plugin adds, say): the page refreshes, so the card goes
  # back where it was, and says why.
  def refuse_move(error)
    flash[:alert] = error.record.errors.full_messages.to_sentence
    render turbo_stream: turbo_stream.refresh(request_id: nil)
  end

  # Your own work unless the filter says otherwise, as on the page (TodosController#index).
  def board_todos
    Todo.filtered(owner: owner_filter_for(params[:owner].presence || "me"), engagement: params[:engagement].presence || "all")
  end

  # The owner param as an id: "me" is the person (for their agent too, the person it acts for),
  # "none" nobody, a name the person it names; the Work page's own filter sends ids.
  def owner_filter_for(owner)
    case owner
    when "any" then "any"
    when "me" then current_user.person.id
    when "none" then nil
    else Agent::Resolver.id?(owner) ? owner : Agent::Resolver.candidates("User", owner).first&.id || 0
    end
  end
end
