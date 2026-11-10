# A contact's own account in the portal: their name, title and phone, whether the portal emails
# them (a message from the team, something they asked for done), and where they're signed in. Their
# address is how we know them, so it changes only through the team.
class Portal::AccountsController < Portal::BaseController
  agent_exempt :show, reason: "the account page; portal_me reads who you act for"
  agent_tool :portal_update_account, on: :update, title: "Change your details",
    description: "Your name, job title and phone, and whether the portal emails you (portal_emails): a message from the team, something you asked for being done.",
    params: { account: { name: "string", title: "string", phone: "string", portal_emails: "boolean" } }

  def show
    load_sessions
  end

  def update
    if current_contact.update(params.expect(account: %i[name title phone portal_emails]))
      redirect_to portal_account_path, notice: "Saved."
    else
      load_sessions
      render :show, status: :unprocessable_entity
    end
  end

  private
    def load_sessions = @sessions = current_contact.portal_sessions.order(updated_at: :desc).to_a
end
