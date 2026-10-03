# Settings > Your account, for everyone: choices that are yours alone, not the install's. Text
# size here beats the install's default (Settings > Appearance).
class Settings::AccountsController < ApplicationController
  allow_staff
  agent_tool :show_account, on: :show, title: "Show your account settings",
    description: "Your own choices: text size (blank follows the install's default)."
  agent_tool :update_account, on: :update, title: "Change your account settings",
    description: "Set your own text size, or blank to follow the install's default.",
    params: { user: { text_size: Setting::TEXT_SIZES.keys + [ "" ] } }

  def show
    @user = Current.user
  end

  def update
    text_size = params.expect(user: [ :text_size ])[:text_size].presence
    Current.user.update!(text_size: text_size.presence_in(Setting::TEXT_SIZES.keys))
    redirect_to settings_account_path, notice: text_size ? "Text size set to #{Setting::TEXT_SIZES[text_size]}." : "Text size follows the install's default."
  end
end
