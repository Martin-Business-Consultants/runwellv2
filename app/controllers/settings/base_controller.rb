# Settings change the app for everyone, so only people who may manage settings reach them.
class Settings::BaseController < ApplicationController
  require_permission :manage_settings
end
