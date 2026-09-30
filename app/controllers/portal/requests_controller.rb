class Portal::RequestsController < Portal::BaseController
  def new
    @request_record = client.requests.new
  end

  def create
    @request_record = client.requests.new(params.expect(request: %i[subject body])
                        .merge(contact: current_contact, sender_name: current_contact.name, sender_email: current_contact.email, source: "portal"))
    if @request_record.save
      @request_record.record_event!("request.received", actor: nil, source: "portal", actor_label: current_contact.name)
      redirect_to portal_root_path, notice: "Sent. We'll get back to you."
    else
      render :new, status: :unprocessable_entity
    end
  end
end
