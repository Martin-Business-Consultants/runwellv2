# The styleguide for Runwell's UI, rune_ui in Runwell's theme (../rune_ui; the bridge in
# app/assets/stylesheets/rune-theme.css): every component, for whoever builds a page or a
# plugin. Development only.
class UiController < ApplicationController
  allow_staff
  agent_exempt :show, reason: "a styleguide for people building pages, not data"

  def show
  end
end
