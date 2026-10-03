# Who a client's agent is acting for: the contact, their client, what they may do, and the
# owner's rule on agents deciding agreements.
class Portal::MesController < Portal::BaseController
  agent_tool :portal_me, on: :show, title: "Who am I acting for, and what can I do",
    description: "The contact and company you act for, whether they can decide agreements (and whether the business lets an agent do it), and what's waiting on them. Call this first."

  def show
    respond_to do |format|
      format.json
      format.html { redirect_to portal_root_path }
    end
  end
end
