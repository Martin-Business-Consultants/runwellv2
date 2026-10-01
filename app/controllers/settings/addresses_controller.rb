# Settings > Address: where people reach this install. Every link Runwell sends (approval links,
# portal sign-ins, invitations, notifications) points here. APP_HOST in the environment is the
# default for installs that set it; this wins once saved.
class Settings::AddressesController < Settings::BaseController
  agent_tool :show_address, on: :show, title: "Show the address links in Runwell's email point to"
  agent_tool :update_address, on: :update, title: "Set the address people reach Runwell at",
    description: "app_url: the install's address, like https://runwell.example.com (a bare host means https). Every link in email (approvals, portal sign-ins, invitations, notifications) points there.",
    params: { setting: { app_url: "string!" } }

  def show
    @setting = Setting.current
  end

  def update
    @setting = Setting.current

    if @setting.update(app_url: params.expect(setting: [ :app_url ])[:app_url])
      redirect_to settings_address_path, notice: "Links in email now point to #{Runwell.url}."
    else
      redirect_to settings_address_path, alert: @setting.errors.full_messages.to_sentence
    end
  end
end
