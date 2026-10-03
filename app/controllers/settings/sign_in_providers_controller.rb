# Saves one sign-in provider's keys and switch (Settings > Sign-in). A blank secret keeps the
# saved one.
class Settings::SignInProvidersController < Settings::BaseController
  agent_exempt :update, reason: "sign-in providers' keys are managed by a person in the browser"

  def update
    provider = SignInProvider.for(params[:key])
    attrs = params.expect(sign_in_provider: %i[client_id client_secret tenant_id enabled])
    attrs.delete(:client_secret) if attrs[:client_secret].blank?
    if provider.update(attrs)
      redirect_to settings_sign_in_path, notice: "#{provider.name} sign-in #{provider.usable? ? "is on" : "saved, and off"}."
    else
      redirect_to settings_sign_in_path, alert: "#{provider.name}: #{provider.errors.full_messages.to_sentence}."
    end
  end
end
