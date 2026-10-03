# Signing in with Google, Microsoft or GitHub. The keys aren't here: each provider's setup phase
# reads the ones the owner saved in Settings > Sign-in (SignInProvider.configure), so turning one
# on needs no restart. Starting a sign-in is a POST with the CSRF token
# (omniauth-rails_csrf_protection); the answer lands on Sessions::OmniauthsController.
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, setup: ->(env) { SignInProvider.configure(env["omniauth.strategy"], "google_oauth2") },
    scope: "email,profile", prompt: "select_account"
  provider :entra_id, setup: ->(env) { SignInProvider.configure(env["omniauth.strategy"], "entra_id") }
  provider :github, setup: ->(env) { SignInProvider.configure(env["omniauth.strategy"], "github") }, scope: "user:email"
  provider :openid_connect, setup: ->(env) { SignInProvider.configure(env["omniauth.strategy"], "openid_connect") }
end

OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.logger = Rails.logger
OmniAuth.config.on_failure = ->(env) { Sessions::OmniauthsController.action(:failure).call(env) }

# Behind a proxy the request may not know the install's address; once it's set (Settings >
# Address), the callback is built from that, as every emailed link is.
OmniAuth.config.full_host = ->(env) { Runwell.host_set? ? "#{Runwell.protocol}://#{Runwell.host}" : Rack::Request.new(env).base_url }
