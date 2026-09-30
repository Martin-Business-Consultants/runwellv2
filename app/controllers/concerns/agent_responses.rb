# How the same controllers answer an agent (a bearer-token request) without a second API.
#
# Reads render their `.json.jbuilder` view. Writes run exactly as they do for a browser, and
# their answer is translated here: a redirect with a notice becomes { status: "ok", summary },
# a redirect with an alert or a 422 re-render becomes { status: "error", errors } (read from the
# record the action was saving), with `path` naming where a browser would have gone so the
# caller can read it. Permissions, validations, events and model verbs are the UI's own.
module AgentResponses
  extend ActiveSupport::Concern

  included do
    around_action :answer_agent, if: :bearer_request?
    skip_forgery_protection if: :bearer_request?
    rescue_from ActiveRecord::RecordNotFound, ActionController::ParameterMissing, ActionController::BadRequest,
      ActionView::MissingTemplate, with: :agent_failure
  end

  private
    def answer_agent
      request.format = :json if request.get?
      yield
      translate_for_agent unless response.media_type == "application/json"
    end

    def translate_for_agent
      envelope =
        if response.redirect?
          location = URI(response.location).path
          response.headers.delete("Location")
          if flash[:alert].present?
            invalid = record_errors
            { status: "error", code: invalid.any? ? "invalid" : "refused", summary: flash[:alert], errors: invalid.presence, path: location }.compact
          else
            { status: "ok", summary: flash[:notice].presence || "Done.", path: location }
          end
        elsif response.status == 422
          messages = record_errors
          { status: "error", code: "invalid", summary: messages.to_sentence.presence || "That didn’t save.", errors: messages }
        else
          ok = response.successful?
          { status: ok ? "ok" : "error", code: (Agent::Errors.code_for_status(response.status) unless ok), summary: flash[:notice] || flash[:alert] || (ok ? "Done." : "That didn’t work.") }.compact
        end

      flash.discard
      response.status = envelope[:status] == "ok" ? 200 : (response.status == 422 || response.redirect? ? 422 : response.status)
      response.content_type = "application/json"
      response.body = envelope.to_json
    end

    def record_errors = view_assigns.values.select { it.respond_to?(:errors) && it.errors.any? }.flat_map { it.errors.full_messages }

    def agent_failure(error)
      raise error unless bearer_request?

      status, code, summary =
        case error
        when ActiveRecord::RecordNotFound then [ :not_found, "not_found", "Not found: it doesn’t exist, or it was removed." ]
        when ActionView::MissingTemplate then [ :not_acceptable, "usage", "This page has no JSON answer yet." ]
        else [ :bad_request, "usage", error.message ]
        end
      render json: { status: "error", code: code, summary: summary, hint: Agent::Errors.hint(code) }, status: status
    end
end
