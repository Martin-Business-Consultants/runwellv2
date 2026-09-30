# Who may do what. Every staff action declares a rule, or it is refused before it runs:
#
#   allow_staff                                        # anyone signed in
#   require_permission :delete_records, only: :destroy # and User#can?(:delete_records)
#
# An action with no rule raises Authorization::MissingRule, so a new action can't ship
# unguarded. Pages open to the public (allow_unauthenticated_access) skip this. Record rules
# (a document its uploader may delete) live on the model and are checked in the action.
module Authorization
  extend ActiveSupport::Concern

  class MissingRule < StandardError; end

  Rule = Data.define(:permission, :only, :except) do
    def applies?(action) = (only.nil? || only.include?(action)) && !except&.include?(action)
  end

  included do
    class_attribute :authorization_rules, instance_accessor: false, default: []
    before_action :authorize_action
    helper_method :can?
  end

  class_methods do
    def allow_staff(only: nil, except: nil) = add_authorization_rule(nil, only, except)
    def require_permission(permission, only: nil, except: nil) = add_authorization_rule(permission, only, except)

    private
      def add_authorization_rule(permission, only, except)
        self.authorization_rules += [ Rule.new(permission, only && Array(only).map(&:to_s), except && Array(except).map(&:to_s)) ]
      end
  end

  private
    def can?(permission) = Current.user&.can?(permission) || false

    def authorize_action
      rules = self.class.authorization_rules.select { it.applies?(action_name) }
      raise MissingRule, "#{self.class.name}##{action_name} declares no authorization rule" if rules.empty?

      deny_access unless rules.filter_map(&:permission).all? { can?(it) }
    end

    def deny_access
      return render(json: { status: "error", code: "forbidden", summary: "Your role can’t do that. Call `me` to see what it can.", hint: Agent::Errors.hint("forbidden") }, status: :forbidden) if Current.agent?

      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: "You don’t have permission to do that." }
        format.any { head :forbidden }
      end
    end
end
