# RubyLLM (in-app AI, Settings > AI). No keys here: each request builds a context from the
# install's own settings (Setting#ai_context), so a key changes without a restart and nothing is
# configured globally.
RubyLLM.configure do |config|
  config.logger = Rails.logger
  config.request_timeout = 120
end
