# Make this a commitment: work that was really a promise becomes one (Todo#convert_to_commitment!).
class Todos::CommitmentsController < ApplicationController
  allow_staff
  agent_tool :convert_work_to_commitment, on: :create, title: "Turn a todo into a commitment",
    description: "For work that is really a dated promise. owner_kind: us (the todo's owner, else you) or client. due_on: blank keeps the todo's date (or a week from now). Its notes and documents move to the engagement; refused if a plugin keeps something on it (logged time, a QA gate) or it's done.",
    params: { owner_kind: Commitment::OWNER_KINDS, due_on: "date" }

  def create
    todo = Todo.find(params[:todo_id])
    commitment = todo.convert_to_commitment!(owner_kind: params[:owner_kind], due_on: params[:due_on])
    redirect_to engagement_path(todo.engagement, tab: "commitments"),
      notice: "“#{todo.title}” is now a #{Setting.current.term(:commitment).downcase}: #{commitment.owner_name} by #{I18n.l(commitment.due_on, format: :short)}."
  rescue Todo::ConversionRefused, ActiveRecord::RecordInvalid => error
    redirect_to todo_path(todo), alert: error.message
  end
end
