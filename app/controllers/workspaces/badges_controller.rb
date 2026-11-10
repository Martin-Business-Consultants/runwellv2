# What another install linked to one of our people (WorkspaceLink) may read with the key we gave
# it: our name, icon and colour, that person's unread notifications and what's waiting in Intake.
# Nothing else answers to that key.
class Workspaces::BadgesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 120, within: 1.minute, with: -> { head :too_many_requests }

  def show
    link = WorkspaceLink.for_key(request.authorization.to_s.delete_prefix("Bearer "))
    return head(:unauthorized) unless link

    response.headers["Cache-Control"] = "no-store"
    render json: { **WorkspaceLink.identity(request.base_url),
      unread: link.user.notifications.unread.count, intake: Task.intake.count }
  end
end
