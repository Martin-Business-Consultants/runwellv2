# What a client's contacts ask for: each request becomes work on their client that nobody has taken
# on yet (a request, Task.requests), with who asked and how. The list shows what the client's
# people asked for and how far it has got.
class Portal::RequestsController < Portal::BaseController
  agent_tool :portal_requests, on: :index, title: "What you've asked for",
    description: "Your requests, newest first, with whether each is still waiting, being worked on, or done."
  agent_tool :portal_send_request, on: :create, title: "Ask for something",
    description: "A request they take on: a short subject and what you need (and by when) in body. Show the person what you'll send first.",
    params: { request: { subject: "string!", body: "text" } }

  def index
    @requests = Task.where(client: client).where.not(contact_id: nil).client_visible.order(created_at: :desc).limit(100)
  end

  def new
    @request_record = client.tasks.new
  end

  def create
    asked = params.expect(request: %i[subject body])
    @request_record = client.tasks.new(title: asked[:subject], description: asked[:body], contact: current_contact,
                                       sender_name: current_contact.name, sender_email: current_contact.email,
                                       source: Current.client_agent? ? "agent" : "portal")
    if @request_record.save
      @request_record.record_event!("task.requested", actor: nil, source: @request_record.source, actor_label: requester_label)
      redirect_to portal_requests_path, notice: "Sent. We'll get back to you."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def requester_label = Current.client_agent? ? "#{current_contact.name} via #{Current.access_token.name}" : current_contact.name
end
