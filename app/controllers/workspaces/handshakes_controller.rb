# Between two installs, server to server (WorkspaceLink): B posts here, for someone who confirmed a
# link this install started, with the nonce and a key for us, and gets our key back (complete!).
# DELETE with our key is B saying it unlinked: we drop our half.
class Workspaces::HandshakesController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection
  rate_limit to: 30, within: 1.minute, with: -> { render json: { error: "Too many tries: wait a minute" }, status: :too_many_requests }

  def create
    key = WorkspaceLink.complete!(nonce: params[:nonce].to_s, url: params[:url].to_s, key: params[:key].to_s,
      identity: params.permit(:name, :icon_url, :color).to_h)
    response.headers["Cache-Control"] = "no-store"
    render json: { key: key, **WorkspaceLink.identity(request.base_url) }
  rescue WorkspaceLink::Refused => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def destroy
    link = WorkspaceLink.for_key(request.authorization.to_s.delete_prefix("Bearer "))
    link&.destroy!
    head(link ? :no_content : :not_found)
  end
end
