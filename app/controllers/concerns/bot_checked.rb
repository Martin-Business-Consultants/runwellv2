# The public forms a bot would fill (sign-in, the emailed sign-in link, sign-up, password reset,
# the portal's sign-in): with a bot check set up (BotCheck), their create refuses a submission the
# provider doesn't vouch for. `bot_checked fallback: -> { new_session_path }` in the controller.
module BotChecked
  extend ActiveSupport::Concern

  class_methods do
    def bot_checked(fallback:, only: :create)
      before_action(only: only) do
        check = BotCheck.new
        next unless check.enabled?
        next if check.passed?(params[check.token_param], remote_ip: request.remote_ip)

        redirect_to instance_exec(&fallback), alert: "Please confirm you’re not a robot, then try again."
      end
    end
  end
end
