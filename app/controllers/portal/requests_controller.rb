class Portal::RequestsController < Portal::BaseController
  agent_tool :portal_requests, on: :index, title: "What you've asked for",
    description: "Your requests, newest first, with whether each is still open, became work, or was closed."
  agent_tool :portal_send_request, on: :create, title: "Ask for something",
    description: "A request they triage: a short subject and what you need (and by when) in body. Show the person what you'll send first.",
    params: { request: { subject: "string!", body: "text" } }

  def index
    @requests = client.requests.ordered.limit(100)
  end

  def new
    @request_record = client.requests.new
  end

  def create
    @request_record = client.requests.new(params.expect(request: %i[subject body])
                        .merge(contact: current_contact, sender_name: current_contact.name, sender_email: current_contact.email,
                               source: Current.client_agent? ? "agent" : "portal"))
    if @request_record.save
      @request_record.record_event!("request.received", actor: nil, source: @request_record.source, actor_label: requester_label)
      redirect_to portal_requests_path, notice: "Sent. We'll get back to you."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def requester_label = Current.client_agent? ? "#{current_contact.name} via #{Current.access_token.name}" : current_contact.name
end
