# What a client's contacts ask for: each request becomes work on their client that nobody has taken
# on yet (a request, Task.requests), with who asked and how. The list shows everything asked for on
# the client's behalf (in the portal, by email, or logged for them by the team) and how far it has
# got; each opens in the side sheet, with its discussion.
class Portal::RequestsController < Portal::BaseController
  include PortalUploads

  agent_tool :portal_requests, on: :index, title: "What you've asked for",
    description: "Your requests, newest first, with whether each is received (nobody has taken it on yet), planned, in progress, on hold or done. portal_task shows one with its discussion."
  agent_tool :portal_send_request, on: :create, title: "Ask for something",
    description: "A request they take on: a short subject and what you need in body. work: the piece of work it's about (its ref or title), if any; due_on: when it's needed by.",
    params: { request: { subject: "string!", body: "text", work: "string", due_on: "date", files: "file[]" } },
    confirm: "It goes to the team in the person’s name. Show them the subject and details first.", next_tools: %i[portal_requests]

  def index
    asked = client.tasks.client_visible.where("tasks.contact_id IS NOT NULL OR COALESCE(tasks.sender_email, '') != '' OR COALESCE(tasks.sender_name, '') != ''")
    @requests = portal_page(asked.includes(:work).order(created_at: :desc, id: :desc))
  end

  def new
    @request_record = client.tasks.new(work: about_work)
  end

  def create
    asked = params.expect(request: [ :subject, :body, :work, :due_on, files: [] ])
    @request_record = client.tasks.new(title: asked[:subject], description: asked[:body], work: about_work(asked[:work]), due_on: asked[:due_on].presence,
                                       contact: current_contact, sender_name: current_contact.name, sender_email: current_contact.email,
                                       source: Current.client_agent? ? "agent" : "portal", requested: true)
    if @request_record.save
      notice = "Sent. We’ll get back to you.#{refused_files_notice(attach_portal_files(@request_record, asked[:files]))}"
      # From the modal over any portal page: it closes and the page shows the request in place.
      return render(turbo_stream: [ turbo_stream.update("modal"), turbo_stream_flash(notice: notice), turbo_stream.refresh(request_id: nil) ]) if from_modal?

      redirect_to portal_requests_path, notice: notice
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    # The piece of work a request is about: one of the client's own that's still going, by ref or title.
    def about_work(name = params[:work])
      return if name.blank?

      client.works.open.find_by(ref: name.to_s.upcase) || client.works.open.find_by(title: name.to_s)
    end
end
