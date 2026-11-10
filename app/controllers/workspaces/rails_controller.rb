# The workspace rail's frame (layouts/shared/_workspace_rail), loaded after the page and every two
# minutes: each linked install asked for its counts at once (threads, a few seconds at most), then
# the rail redrawn with them.
class Workspaces::RailsController < ApplicationController
  allow_staff
  agent_exempt :show, reason: "the rail is the browser's view of other installs; agents use each install's own tools"

  def show
    links = Current.user.workspace_links.linked.ordered.to_a
    answers = links.map { |link| Thread.new { link.fetch_badges } }.map(&:value)
    links.zip(answers).each { |link, answer| link.store_badges(answer) unless link.badges_at && link.badges_at > WorkspaceLink::BADGE_TTL.ago }
    render partial: "layouts/shared/workspace_rail", locals: { links: links }
  end
end
