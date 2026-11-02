# Settings > Setup: the first-run checklist (Setup), the few things a new install needs before
# Runwell is useful, each checked off by what exists. Owners land here from the gear until the
# required steps are done.
class Settings::SetupsController < Settings::BaseController
  agent_tool :show_setup, on: :show, title: "Show the setup checklist",
    description: "What a new install still needs (address, mail, a first client…), each step done or not, with where to do it."

  def show
    @setup = Setup.new(current_user)
  end
end
