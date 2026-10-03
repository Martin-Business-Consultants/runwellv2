# Settings > Sign-in: sign in only through Google, Microsoft, GitHub or single sign-on. Owners
# keep their password, so a provider being down can't lock the install.
class Settings::ProvidersOnliesController < Settings::BaseController
  agent_exempt :update, reason: "sign-in security is changed by a person in the browser"

  def update
    on = params.dig(:setting, :providers_only) == "1"
    if on && SignInProvider.usable_keys.empty?
      return redirect_to(settings_sign_in_path, alert: "Switch on a provider first, or nobody but owners could sign in.")
    end

    Setting.current.update!(providers_only: on)
    Setting.current.record_event!("settings.providers_only", payload: { on: on })
    redirect_to settings_sign_in_path, notice: on ? "Only #{SignInProvider.usable_keys.map { SignInProvider.name_for(it) }.to_sentence(last_word_connector: " or ")} from now on (owners keep their password)." : "Passwords and links work again."
  end
end
