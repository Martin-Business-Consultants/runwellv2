class QuestionsController < ApplicationController
  allow_staff
  agent_tool :answer_question, on: :answer, title: "Answer a question", params: { answer: "string!" }
  agent_tool :dismiss_question, on: :dismiss, title: "Dismiss a question"

  before_action :set_question

  def answer
    @question.answer!(params.require(:answer))
    redirect_back fallback_location: root_path, notice: "Answered."
  end

  def dismiss
    @question.dismiss!
    redirect_back fallback_location: root_path, notice: "Dismissed."
  end

  private

  def set_question = @question = current_user.questions.find(params[:id])
end
