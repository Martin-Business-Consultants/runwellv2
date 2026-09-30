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

  def board_todos
    Todo.filtered(owner: params[:owner].presence || "any", engagement: params[:engagement].presence || "all")
  end
end
