class Settings::AppearancesController < Settings::BaseController
  agent_tool :show_appearance, on: :show, title: "Show appearance settings"
  agent_tool :update_appearance, on: :update, title: "Change appearance",
    params: { setting: { theme: Setting::THEMES.keys, radius: Setting::RADII.keys, scheme: Setting::SCHEMES.keys, font: Setting::FONTS.keys, text_size: Setting::TEXT_SIZES.keys, custom_css: "text", custom_css_everywhere: "boolean", logo: "file", favicon: "file" }, remove: %w[logo favicon] }

  def show
    @setting = Setting.with_attached_logo.with_attached_favicon.find(Setting.current.id)
  end

  def update
    setting = Setting.current
    if setting.update(params.fetch(:setting, {}).permit(:theme, :radius, :scheme, :font, :text_size, :custom_css, :custom_css_everywhere, :logo, :favicon))
      setting.record_event!("settings.custom_css", payload: { digest: (setting.custom_css_digest if setting.custom_css) }) if setting.saved_change_to_custom_css?
      setting.logo.purge if params[:remove] == "logo"
      setting.favicon.purge if params[:remove] == "favicon"
      redirect_to settings_appearance_path, notice: "Appearance saved."
    else
      # Keep what was typed (a stylesheet it refused) on the page, with why.
      @setting = setting
      ActiveRecord::Associations::Preloader.new(records: [ @setting ], associations: %i[logo_attachment favicon_attachment]).call
      render :show, status: :unprocessable_entity
    end
  end
end
