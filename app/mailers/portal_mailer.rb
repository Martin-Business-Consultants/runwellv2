# What the portal emails a client's people: the way in (a sign-in link, an invitation), a message
# from the team on one of their tasks, and that something they asked for is done. The last two go
# only to contacts who still want them (Contact#portal_emails, their account in the portal).
class PortalMailer < ApplicationMailer
  # return_to: the portal page they were after, so the link lands there on whatever device opens it.
  def magic_link
    @contact = params[:contact]
    @url = portal_session_link_url(@contact.generate_token_for(:portal_login), return_to: params[:return_to].presence)
    mail to: @contact.email, subject: "Your sign-in link for #{Setting.current.brand_name}"
  end

  def invitation
    @contact = params[:contact]
    @url = portal_session_link_url(@contact.generate_token_for(:portal_invite))
    mail to: @contact.email, subject: "#{Setting.current.brand_name} set up a portal for you"
  end

  # The team wrote on a task's discussion (Tasks::DiscussionsController, reply_to_client).
  def reply
    @note, @contact = params[:note], params[:contact]
    @task = @note.subject
    return unless @contact.portal? && @task.client_visible?

    @url = portal_tasks_url(task: @task.id)
    mail to: @contact.email, subject: "New message: #{@task.title}"
  end

  # Something they asked for was marked done. Checked again here: an Undo since sends nothing.
  def done
    @task, @contact = params[:task], params[:contact]
    return unless @task.status == "done" && @task.client_visible? && @contact.portal?

    @url = portal_tasks_url(task: @task.id, status: "all")
    mail to: @contact.email, subject: "Done: #{@task.title}"
  end
end
