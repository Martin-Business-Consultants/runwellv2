class Settings::AppearancesController < Settings::BaseController
  agent_tool :show_appearance, on: :show, title: "Show appearance settings"
  agent_tool :update_appearance, on: :update, title: "Change appearance",
    params: { setting: { theme: Setting::THEMES.keys, radius: Setting::RADII.keys, scheme: Setting::SCHEMES.keys, font: Setting::FONTS.keys, logo: "file", favicon: "file" }, remove: %w[logo favicon] }

  def show
    @setting = Setting.current
  end

  def update
    setting = Setting.current
    setting.update!(params.fetch(:setting, {}).permit(:theme, :radius, :scheme, :font, :logo, :favicon))
    setting.logo.purge if params[:remove] == "logo"
    setting.favicon.purge if params[:remove] == "favicon"
    redirect_to settings_appearance_path, notice: "Appearance saved."
  end
end
