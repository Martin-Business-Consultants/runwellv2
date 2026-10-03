module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    # Public pages also skip authorization (Authorization): there is no one to check.
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
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

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
