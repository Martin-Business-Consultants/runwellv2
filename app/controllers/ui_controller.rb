# The styleguide of the compatibility layer (RuneCompatHelper, runwell/compat.css): rune_ui's
# helpers and classes as plugins written before 6.0 use them, drawn by runeui, until 7.0. New
# markup is runeui's (its gallery is /runeui). Development only.
class UiController < ApplicationController
  allow_staff
  agent_exempt :show, reason: "a styleguide for people building pages, not data"

  def show
  end
end
