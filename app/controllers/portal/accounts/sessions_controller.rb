# Signing out of the portal everywhere else: every other browser the contact is signed in with.
class Portal::Accounts::SessionsController < Portal::BaseController
  browser_only :destroy, reason: "a person signing their other browsers out"

  def destroy
    others = current_contact.portal_sessions.where.not(id: Current.portal_session&.id)
    count = others.count
    others.destroy_all
    redirect_to portal_account_path, notice: count.zero? ? "You’re only signed in here." : "Signed out of #{helpers.pluralize(count, "other browser")}."
  end
end
