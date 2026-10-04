# A conversation with the in-app AI: one person's, about a record or nothing in particular, for
# the Ask panel (purpose "ask") or a suggestion on a record ("suggestion", AiSuggestion). RubyLLM's
# Rails integration (acts_as_chat) keeps its messages, tool calls and usage; Runwell adds whose it
# is, what it's about, the install's provider (Setting#ai_context, set as each chat loads) and,
# for each reply, fresh instructions and the tools in Ai::Tools.
#
# A reply runs in a job (AiReplyJob) while replying_since is set; the panel polls until it's
# cleared. A change the model proposes pauses the chat until the person approves or declines it
# (RubyLLM's persisted approvals), then the job carries on.
class AiChat < ApplicationRecord
  acts_as_chat messages: :ai_messages

  PURPOSES = %w[ask suggestion].freeze
  SUBJECT_TYPES = %w[Client Engagement Todo Request ScopeItem].freeze
  TOOLS = [ Ai::Tools::Search, Ai::Tools::ReadRecord, Ai::Tools::FindTools, Ai::Tools::RunTool ].freeze
  STUCK_AFTER = 5.minutes

  belongs_to :user, optional: true
  belongs_to :contact, optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validate { errors.add(:base, "A chat belongs to a person on staff or a client's contact") unless user.present? ^ contact.present? }

  validates :purpose, inclusion: { in: PURPOSES }

  scope :recent, -> { order(updated_at: :desc) }
  scope :asks, -> { where(purpose: "ask") }

  after_initialize :use_install_provider

  # A chat on the install's model (or its fast one), ready to ask.
  def self.start!(user: nil, contact: nil, subject: nil, purpose: "ask", fast: false)
    setting = Setting.current
    raise Ai::Unavailable, "AI isn't set up: Settings > AI." unless setting.ai_ready?

    model = setting.ai_model_for(fast: fast)
    route = setting.ai_route(model)
    register_model(model, route[:provider])
    new(user: user, contact: contact, subject: subject, purpose: purpose)
      .with_model(model, provider: route[:provider], protocol: route[:protocol], assume_model_exists: true)
  end

  # RubyLLM keeps a row per model its chats use. Runwell reads models from RubyLLM's bundled
  # registry, so only this one row is needed; making it first spares copying the whole registry
  # into the database on an install's first chat.
  def self.register_model(model_id, provider)
    info = begin
      RubyLLM.models.find(model_id, provider: provider)
    rescue RubyLLM::ModelNotFoundError
      RubyLLM::Model.default(model_id, provider)
    end
    RubyLLM::ActiveRecord::Model.find_or_create_by!(model_id: info.id, provider: info.provider) do |record|
      record.name = info.name || info.id
      record.family = info.family
      record.context_window = info.context_window
      record.max_output_tokens = info.max_output_tokens
      record.capabilities = info.capabilities || []
      record.modalities = info.modalities.to_h
      record.pricing = info.pricing.to_h
      record.metadata = info.metadata || {}
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  # The person's ongoing chat about this record (from the last half day), or a new one.
  def self.for(user, subject)
    asks.where(user: user, subject: subject).where(updated_at: 12.hours.ago..).recent.first || start!(user: user, subject: subject)
  end

  # A client contact's ongoing chat in the portal (Settings > AI lets clients ask), or a new one.
  def self.for_contact(contact)
    asks.where(contact: contact).where(updated_at: 12.hours.ago..).recent.first || start!(contact: contact)
  end

  def portal? = contact.present?

  # RubyLLM doesn't keep the wire protocol, so it's worked out again from the model (OpenCode Zen
  # reaches some models by chat completions; everything else uses the provider's own).
  def protocol
    super || (Setting.current.ai_route(model_id)[:protocol] if Setting.current.ai_provider == "opencode")
  end

  def replying? = replying_since.present? && replying_since > STUCK_AFTER.ago

  # Files the model can read alongside a question: PDFs, images and text.
  READABLE = %r{\A(application/pdf|image/(png|jpeg|gif|webp)|text/)}

  # The record's documents that can go with a question.
  def attachable_documents
    return Document.none unless subject.respond_to?(:documents)

    subject.documents.recent.includes(file_attachment: :blob).limit(8).select { it.content_type.to_s.match?(READABLE) }
  end

  # The person asks (with any of the record's documents attached): their message is saved now,
  # the reply written by a job.
  def ask_soon!(text, document_ids: [])
    raise Ai::Unavailable, "AI is off for this #{Setting.current.term(:client).downcase}." if Ai.excluded?(portal? ? contact.client : subject)
    raise Ai::Unavailable, "This month's AI budget is spent: Settings > AI." if Ai.over_budget?
    raise Ai::Unavailable, "Approve or decline the change above first." if proposals.any?

    files = attachable_documents.select { it.id.to_s.in?(Array(document_ids).map(&:to_s)) }.map(&:file)
    ask_later(text.to_s.strip.truncate(8_000), with: files.presence)
    update!(title: title.presence || text.to_s.squish.truncate(80), replying_since: Time.current)
    AiReplyJob.perform_later(self)
  end

  # The person decides on a proposed change, then the chat carries on (running it, or telling
  # the model it was declined).
  def decide!(tool_call_id, approve:)
    approve ? approve(tool_call_id) : deny(tool_call_id)
    update!(replying_since: Time.current)
    AiReplyJob.perform_later(self)
  end

  # Called by AiReplyJob: runs the conversation on (answering the question, or past a decision),
  # writing the reply into its message as it streams so the panel shows it coming.
  def reply!
    with_instructions(portal? ? Ai::Instructions.for_portal(self) : Ai::Instructions.for(self), persist: false)
    with_tools(*(portal? ? [ Ai::Tools::PortalAction.new(self) ] : TOOLS.map { it.new(self) }))

    buffer = +""
    written_at = Time.current
    complete do |chunk|
      buffer << chunk.content.to_s
      next if Time.current - written_at < 0.4

      ai_messages.where(role: "assistant").last&.update_columns(content: buffer)
      written_at = Time.current
    end
  rescue Ai::Unavailable, RubyLLM::Error, Faraday::Error, Timeout::Error => error
    ai_messages.create!(role: "assistant", content: "I couldn’t answer: #{error.message.truncate(300)}")
  ensure
    update_columns(replying_since: nil, updated_at: Time.current)
  end

  # The changes waiting on the person: run_tool calls of an action that writes, with no decision
  # and no result yet (RubyLLM's own records, read without building the chat).
  def proposals
    return [] if replying?

    RubyLLM::ActiveRecord::ToolCall.where(message_type: "AiMessage", message_id: ai_messages.select(:id), name: %w[run_tool portal_action], approval: nil, result_id: nil)
      .select { (action = Agent::Catalogue.find(it.arguments.to_h.stringify_keys["name"])) && !action.read? }
  end

  private
    def use_install_provider
      self.assume_model_exists = true
      self.context = Setting.current.ai_context if Setting.current.ai_ready?
    end
end
