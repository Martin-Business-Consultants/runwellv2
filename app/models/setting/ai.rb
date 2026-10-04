# Settings > AI: the install's own AI, through RubyLLM. The owner picks a provider and pastes its
# key (encrypted), or points at their own Ollama; nothing is sent anywhere until it's switched on.
# A monthly budget, in cents, stops new requests once spent (Ai.over_budget?).
module Setting::Ai
  extend ActiveSupport::Concern

  AI_PROVIDERS = {
    "anthropic" => { name: "Anthropic (Claude)", model: "claude-sonnet-5", fast: "claude-haiku-4-5", key: true },
    "openai" => { name: "OpenAI", model: "gpt-5.6", fast: "gpt-5.4-mini", key: true },
    "gemini" => { name: "Google Gemini", model: "gemini-pro-latest", fast: "gemini-flash-latest", key: true },
    "openrouter" => { name: "OpenRouter (any model)", model: "anthropic/claude-sonnet-5", fast: "anthropic/claude-haiku-4-5", key: true },
    "opencode" => { name: "OpenCode Zen (Claude, GPT, Gemini and open models on one key)", model: "claude-sonnet-5", fast: "claude-haiku-4-5", key: true, base: "https://opencode.ai/zen/v1" },
    "ollama" => { name: "Ollama (your own server, nothing leaves it)", model: "llama4", fast: "llama4", key: false, base: "http://localhost:11434/v1" }
  }.freeze

  included do
    encrypts :ai_api_key
    validates :ai_provider, inclusion: { in: AI_PROVIDERS.keys }, allow_nil: true
    validates :ai_monthly_budget_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
    validate :ai_complete, if: :ai_enabled?
  end

  # Switched on, with what it needs to reach the provider.
  def ai_ready? = ai_enabled? && ai_provider.present? && (ai_api_key.present? || !AI_PROVIDERS.dig(ai_provider, :key))

  def ai_provider_name = AI_PROVIDERS.dig(ai_provider, :name)
  # The model id as the provider takes it ("opencode/claude-sonnet-5" as OpenCode lists it works too).
  def ai_model_for(fast: false)
    ((fast ? ai_fast_model.presence : nil) || ai_model.presence || AI_PROVIDERS.dig(ai_provider, fast ? :fast : :model)).to_s.delete_prefix("opencode/")
  end

  # Which RubyLLM provider and wire protocol reach a model. One provider is one route, except
  # OpenCode Zen, which serves each family of models its own way behind one key (opencode.ai/docs/zen):
  # Claude and most Qwen as Anthropic's Messages, GPT, Grok and Muse as OpenAI's Responses, Gemini
  # as Google's, and the rest (DeepSeek, Kimi, GLM, MiniMax, Qwen3.8 Max, the free ones) as OpenAI
  # chat completions.
  def ai_route(model_id)
    return { provider: ai_provider.to_sym, protocol: nil } unless ai_provider == "opencode"

    case model_id.to_s
    when /\Aqwen3\.8-max/ then { provider: :openai, protocol: :chat_completions }
    when /\A(claude|qwen)/ then { provider: :anthropic, protocol: nil }
    when /\A(gpt|grok|muse|o\d)/ then { provider: :openai, protocol: nil }
    when /\Agemini/ then { provider: :gemini, protocol: nil }
    else { provider: :openai, protocol: :chat_completions }
    end
  end

  # How a model is reached, in words, for errors and the connection test.
  def ai_route_name(model_id)
    route = ai_route(model_id)
    endpoint = { anthropic: "Anthropic Messages", gemini: "Google" }[route[:provider]] ||
      (route[:protocol] == :chat_completions ? "chat completions" : (ai_provider == "openai" || ai_provider == "opencode" ? "OpenAI Responses" : nil))
    [ model_id, ("through #{ai_provider_name.to_s.split(" (").first}#{"’s #{endpoint} endpoint" if endpoint}" if ai_provider == "opencode") ].compact.join(" ")
  end

  # A RubyLLM context with this install's provider settings, leaving the global config alone.
  def ai_context
    RubyLLM.context do |config|
      case ai_provider
      when "anthropic" then config.anthropic_api_key = ai_api_key
      when "openai" then config.openai_api_key = ai_api_key
      when "gemini" then config.gemini_api_key = ai_api_key
      when "openrouter" then config.openrouter_api_key = ai_api_key
      when "ollama"
        config.ollama_api_base = ai_api_base.presence || AI_PROVIDERS.dig("ollama", :base)
        config.ollama_api_key = ai_api_key.presence
      end
      if ai_provider == "opencode"
        base = (ai_api_base.presence || AI_PROVIDERS.dig("opencode", :base)).chomp("/")
        config.openai_api_key = config.anthropic_api_key = config.gemini_api_key = ai_api_key
        config.openai_api_base = base
        config.gemini_api_base = base
        config.anthropic_api_base = base.delete_suffix("/v1")
      end
      config.openai_api_base = ai_api_base if ai_provider == "openai" && ai_api_base.present?
      config.request_timeout = 120
      config.logger = Rails.logger
    end
  end

  private
    def ai_complete
      errors.add(:ai_provider, "is needed to switch AI on") if ai_provider.blank?
      errors.add(:ai_api_key, "is needed for #{ai_provider_name}") if ai_provider.present? && AI_PROVIDERS.dig(ai_provider, :key) && ai_api_key.blank?
    end
end
