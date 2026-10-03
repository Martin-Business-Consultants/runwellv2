# Settings > Webhooks: addresses that hear of events as signed JSON. Data leaves the install from
# here, so adding, changing and removing endpoints is for an owner in the browser; agents may
# only list them (without secrets).
class Settings::WebhooksController < Settings::BaseController
  agent_tool :list_webhooks, on: :index, title: "List webhooks", description: "The addresses events are sent to, which kinds, and how delivery is going. Secrets aren't included."
  agent_exempt :create, :update, :destroy, reason: "webhooks send data out of the install, so a person sets them up in the browser"

  def index
    @endpoints = WebhookEndpoint.ordered.to_a
    @deliveries = WebhookDelivery.where(webhook_endpoint: @endpoints).recent.limit(200).group_by(&:webhook_endpoint_id).transform_values { it.first(8) }
    @endpoint = WebhookEndpoint.new
  end

  def create
    endpoint = WebhookEndpoint.new(endpoint_params.merge(created_by: Current.user))
    if endpoint.save
      Setting.current.record_event!("settings.webhook", payload: { url: endpoint.url, added: true })
      endpoint.ping!
      redirect_to settings_webhooks_path(anchor: dom_id(endpoint)), notice: "Webhook added, and a test sent to it. Its secret is under it, to check signatures."
    else
      redirect_to settings_webhooks_path, alert: endpoint.errors.full_messages.to_sentence
    end
  end

  def update
    endpoint = WebhookEndpoint.find(params[:id])
    if params[:ping]
      endpoint.ping!
      redirect_to settings_webhooks_path(anchor: dom_id(endpoint)), notice: "Test sent."
    elsif endpoint.update(endpoint_params.merge(failures_in_a_row: (0 if params.dig(:webhook_endpoint, :active) == "1")).compact)
      Setting.current.record_event!("settings.webhook", payload: { url: endpoint.url, active: endpoint.active? })
      redirect_to settings_webhooks_path(anchor: dom_id(endpoint)), notice: "Webhook saved."
    else
      redirect_to settings_webhooks_path, alert: endpoint.errors.full_messages.to_sentence
    end
  end

  def destroy
    endpoint = WebhookEndpoint.find(params[:id])
    endpoint.destroy!
    Setting.current.record_event!("settings.webhook", payload: { url: endpoint.url, removed: true })
    redirect_to settings_webhooks_path, notice: "Webhook removed."
  end

  private
    def endpoint_params
      params.expect(webhook_endpoint: %i[url description kinds_text include_security active])
    end

    def dom_id(record) = ActionView::RecordIdentifier.dom_id(record)
end
