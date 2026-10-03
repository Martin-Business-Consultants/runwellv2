# Suggestions the in-app AI makes on records (Ai::Suggestions): asking for one (made in a job;
# its card reloads until ready), showing it, and using or dismissing it. Using one applies it with
# the person's own permissions. Each person's own.
class Ai::SuggestionsController < ApplicationController
  allow_staff
  agent_exempt :create, :show, :update, reason: "the in-app AI's suggestions; agents use the tools directly over MCP"

  def create
    subject = find_subject
    definition = Ai::Suggestions.find(params[:kind])
    raise ActiveRecord::RecordNotFound unless subject && definition.applies_to?(subject)
    return redirect_back(fallback_location: root_path, alert: "AI isn’t available here.") unless Ai.available_for?(subject)

    suggestion = AiSuggestion.create!(user: Current.user, subject: subject, kind: definition.kind)
    AiSuggestionJob.perform_later(suggestion)
    redirect_to ai_suggestion_path(suggestion, row: params[:row])
  end

  def show
    @suggestion = Current.user.ai_suggestions.find(params[:id])
  end

  def update
    suggestion = Current.user.ai_suggestions.find(params[:id])
    if params[:decision] == "dismiss"
      suggestion.dismiss!
      redirect_to ai_suggestion_path(suggestion, row: params[:row])
    else
      notice = suggestion.accept!(params[:items])
      redirect_back fallback_location: root_path, notice: notice
    end
  rescue Ai::Suggestions::Refused, ActiveRecord::RecordInvalid, ArgumentError => error
    redirect_back fallback_location: root_path, alert: error.message
  end

  private
    def find_subject
      type, id = params[:record].to_s.split(":", 2)
      case type
      when "User" then Current.user
      when "Engagement" then Engagement.find_by(ref: id) || Engagement.find_by(id: id)
      when *(Ai::Suggestions::DEFINITIONS.values.flat_map(&:types).uniq - %w[User Engagement]) then type.constantize.find_by(id: id)
      end
    end
end
