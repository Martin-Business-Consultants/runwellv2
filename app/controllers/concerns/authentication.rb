module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    before_action :require_two_factor_setup
    helper_method :authenticated?
  end

  class_methods do
    # Public pages also skip authorization (Authorization): there is no one to check.
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      skip_before_action :require_two_factor_setup, **options
      skip_before_action :authorize_action, **options
      skip_before_action :ensure_agent_declaration, **options, raise: false
      self.agent_public_actions = options[:only] ? Array(options[:only]).map(&:to_s) : :all
    end
  end

  private
    def authenticated?
      Current.access_token.present? || resume_session
    end

    # A browser signs in with its session cookie; an agent, script or the CLI with a bearer
    # token (AccessToken), acting as that token's person.
    def require_authentication
      if bearer_request?
        authenticate_by_token || request_token_authentication
      else
        resume_session || request_authentication
      end
    end

    # The install requires two-factor sign-in (Settings > People) and this person, signed in
    # with a browser, hasn't set it up: every staff page sends them to set it up first. Tokens
    # already made keep working; a new OAuth connection goes through the browser, so it waits too.
    def require_two_factor_setup
      return unless Current.session&.user&.two_factor_setup_required?

      if request.format.html?
        redirect_to new_settings_two_factor_path, alert: "Set up two-factor sign-in to carry on: this install requires it."
      else
        head :forbidden
      end
    end

    def bearer_request? = request.authorization.to_s.start_with?("Bearer ")

    # Staff surfaces take staff tokens only: a client's token reaches the portal and nothing else.
    def authenticate_by_token
      token = AccessToken.authenticate_staff(bearer_token)
      return unless token
      return refuse_paused_token if token.paused?

      token.used!
      Current.access_token = token
    end

    def bearer_token = request.authorization.to_s.delete_prefix("Bearer ").strip

    def refuse_paused_token
      render json: { status: "error", code: "paused", summary: "This connection is paused.", hint: Agent::Errors.hint("paused") }, status: :forbidden
    end

    # 401 with a pointer to how to get a token (OAuth metadata, RFC 9728), so a connector can
    # start signing in on its own.
    def request_token_authentication
      response.headers["WWW-Authenticate"] = %(Bearer resource_metadata="#{oauth_protected_resource_url}")
      render json: { status: "error", code: "auth", summary: "Sign in first: this needs a valid token.", hint: Agent::Errors.hint("auth") }, status: :unauthorized
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    # A deactivated person's sessions are gone, but check anyway.
    def find_session_by_cookie
      Session.joins(:user).merge(User.active).find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    # The first step checked out (a password, an emailed link, Google…): sign in, or go on to the
    # code from the authenticator app when the person has two-factor sign-in on.
    def sign_in_after_first_step(user, method: "password")
      if user.two_factor?
        session[:two_factor] = { "user_id" => user.id, "at" => Time.current.to_i, "tries" => 0, "method" => method }
        redirect_to new_session_two_factor_path
      else
        start_new_session_for user, method: method
        redirect_to after_authentication_url
      end
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    # method: how they got in (password, link, a provider's key, signup, invitation), for the
    # audit log (Settings > Audit log).
    def start_new_session_for(user, method: "password")
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
        user.record_event!("user.signed_in", actor: user, source: "app", actor_label: nil,
          payload: { method: method, two_factor: user.two_factor?, ip: request.remote_ip, browser: request.user_agent.to_s.truncate(120) })
      end
    end

    # A wrong password or code for a real account, for the audit log. Nobody is signed in, so the
    # event has no actor.
    def record_failed_sign_in(user, reason)
      user&.record_event!("user.sign_in_failed", actor: nil, source: "app", actor_label: "unknown",
        payload: { reason: reason, ip: request.remote_ip, browser: request.user_agent.to_s.truncate(120) })
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
