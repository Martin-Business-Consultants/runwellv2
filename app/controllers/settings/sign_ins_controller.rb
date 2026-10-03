# Settings > Sign-in: let people sign in with Google, Microsoft or GitHub. For each, the owner
# registers an app with the provider (the callback address is shown to copy) and saves its keys.
class Settings::SignInsController < Settings::BaseController
  agent_exempt :show, reason: "sign-in providers' keys are managed by a person in the browser"

  def show
    saved = SignInProvider.all.index_by(&:key)
    @providers = SignInProvider::PROVIDERS.keys.map { saved[it] || SignInProvider.new(key: it) }
  end
end
