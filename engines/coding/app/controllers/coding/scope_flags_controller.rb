# When work goes beyond what the client agreed: a request to triage, which a manager can
# promote to a change order. Nothing reaches the client until they do.
module Coding
  class ScopeFlagsController < ApplicationController
    allow_staff
    agent_tool :flag_out_of_scope, on: :create, title: "Flag work that looks outside the agreed scope",
      description: "Compare the work (the diff, or what was asked for) with the agreed scope from checkout_work. When it goes beyond it, flag it: this opens a request to triage on the client, which a manager can promote to a change order. The client sees nothing.",
      params: { scope_flag: { summary: "string!", details: "text" } }

    before_action :set_todo

    def create
      flag = params.expect(scope_flag: %i[summary details])
      request = ::Request.new(client: @todo.client, subject: "Beyond scope? #{flag[:summary]}".truncate(200), source: "scope check",
        sender_name: Current.user.display_name, body: [ flag[:details], "<p>Raised on #{ERB::Util.html_escape(@todo.engagement.ref)}: #{ERB::Util.html_escape(@todo.title)}</p>" ].compact_blank.join)
      if request.save
        request.record_event!("request.received", payload: { todo: @todo.id })
        @todo.record_event!("coding.scope_flagged", payload: { request: request.id })
        redirect_back fallback_location: @todo, notice: "Flagged as a request to triage. Promote it to a change order if the client should agree to it."
      else
        redirect_back fallback_location: @todo, alert: request.errors.full_messages.to_sentence
      end
    end
  end
end
