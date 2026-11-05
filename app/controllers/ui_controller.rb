# The styleguide for Runwell UI, the shadcn/ui port (app/assets/stylesheets/ui): every
# component in every variant, for whoever builds a page or a plugin. Development only.
class UiController < ApplicationController
  allow_staff
  agent_exempt :show, reason: "a styleguide for people building pages, not data"

  def show
  end
end
