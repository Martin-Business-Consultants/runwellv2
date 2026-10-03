# Settings > Address: where people reach this install. Every link Runwell sends (approval links,
# portal sign-ins, invitations, notifications) points here. APP_HOST in the environment is the
# default for installs that set it; this wins once saved.
class Settings::AddressesController < Settings::BaseController
  agent_tool :show_address, on: :show, title: "Show the address links in Runwell's email point to"
  agent_tool :update_address, on: :update, title: "Set the address people reach Runwell at, or the agency's time zone",
    description: "app_url: the install's address, like https://runwell.example.com (a bare host means https). Every link in email (approvals, portal sign-ins, invitations, notifications) points there. time_zone: the agency's zone, as a Rails name (\"Pacific Time (US & Canada)\") or IANA (\"America/Los_Angeles\").",
    params: { setting: { app_url: "string", time_zone: "string" } }

  def show
    @setting = Setting.current
  end

  def update
    @setting = Setting.current

    attributes = params.expect(setting: %i[app_url time_zone])
    if @setting.update(attributes)
      notice = attributes.key?(:time_zone) ? "Times now show in #{Setting.zone.name}." : "Links in email now point to #{Runwell.url}."
      redirect_to settings_address_path(anchor: (attributes.key?(:time_zone) ? "time_zone" : nil)), notice: notice
    else
      redirect_to settings_address_path, alert: @setting.errors.full_messages.to_sentence
    end
  end
end
