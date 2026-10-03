# Settings > AI: the install's own AI (Ai, through RubyLLM). The owner picks a provider, pastes its
# key (encrypted; blank keeps the saved one), chooses models and a monthly budget, and switches it
# on. Shows this month's spend, by person and by kind, and how often suggestions were used.
class Settings::AisController < Settings::BaseController
  agent_tool :show_ai_settings, on: :show, title: "Show AI settings and usage",
    description: "Whether the in-app AI is on, its provider and models (never the key), the monthly budget and this month's spend."
  agent_exempt :update, reason: "the AI provider and its key are set by a person in the browser"

  def show
    @setting = Setting.current
    @spent = Ai.spent
    month = Time.current.beginning_of_month..Time.current
    @by_person = AiChat.joins(:ruby_llm_usages).where(ruby_llm_usages: { created_at: month }).group(:user_id).sum("ruby_llm_usages.total_cost")
    @people = User.where(id: @by_person.keys).index_by(&:id)
    @by_kind = AiChat.joins(:ruby_llm_usages).where(ruby_llm_usages: { created_at: month }).group(:purpose).sum("ruby_llm_usages.total_cost")
    @suggestions = AiSuggestion.where(created_at: month).group(:kind, :state).count
  end

  def update
    setting = Setting.current
    attrs = params.expect(setting: %i[ai_enabled ai_provider ai_api_key ai_api_base ai_model ai_fast_model ai_monthly_budget_cents ai_portal])
    attrs.delete(:ai_api_key) if attrs[:ai_api_key].blank?
    if setting.update(attrs)
      setting.record_event!("settings.ai", payload: { on: setting.ai_enabled?, provider: setting.ai_provider, model: setting.ai_model_for })
      redirect_to settings_ai_path, notice: setting.ai_ready? ? "AI is on, through #{setting.ai_provider_name}." : "AI settings saved#{", and AI is off" unless setting.ai_enabled?}."
    else
      redirect_to settings_ai_path, alert: setting.errors.full_messages.to_sentence
    end
  end
end
