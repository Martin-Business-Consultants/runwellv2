# Where a site reports its own test (its daily canary, a deploy check, a form submission it
# just sent): what it actually did, compared with the check's source of truth. Public, and the
# token in the URL is the check's alone.
#
#   POST /qa/report/:token
#   { "results": { "from_address": "hello@acme-storage.example", "to": ["office@acme-storage.example"],
#                  "webhook_accepted": { "verdict": "pass" } },
#     "reporter": "daily canary", "notes": "…", "evidence_url": "…" }
#
# Answers with each result and any keys the check doesn't have.
module Qa
  class ReportsController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    def create
      check = Check.active.find_by(report_token: params[:token].to_s)
      return render(json: { status: "error", error: "Unknown report URL" }, status: :not_found) unless check

      body = request.content_type.to_s.include?("json") ? JSON.parse(request.raw_post.presence || "{}") : params.to_unsafe_h
      Current.source = "report"
      run = Run.record(check: check, answers: body["results"].to_h, source: "report", user: nil,
        reporter: body["reporter"].to_s.truncate(80).presence || "the site", notes: body["notes"].to_s.truncate(2000), evidence_url: body["evidence_url"])

      if run.persisted?
        render json: { status: "ok", passed: run.passed?, summary: run.summary, unknown_keys: run.unknown_keys,
          results: run.results.map { { key: it.key, expected: it.expected, actual: it.actual, passed: it.passed } } }
      else
        render json: { status: "error", errors: run.errors.full_messages, unknown_keys: run.unknown_keys }, status: :unprocessable_entity
      end
    rescue JSON::ParserError
      render json: { status: "error", error: "The body isn’t JSON" }, status: :bad_request
    end
  end
end
