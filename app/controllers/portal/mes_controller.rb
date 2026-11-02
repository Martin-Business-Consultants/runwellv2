# Who a client's agent is acting for: the contact, their client, and what they may do.
class Portal::MesController < Portal::BaseController
  agent_tool :portal_me, on: :show, title: "Who am I acting for, and what can I do",
    description: "The contact and company you act for, whether they can approve for their company, and their time zone. Call this first."

  def show
    respond_to do |format|
      format.json
      format.html { redirect_to portal_root_path }
    end
  end
end
