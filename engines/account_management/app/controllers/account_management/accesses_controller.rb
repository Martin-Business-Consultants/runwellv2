# The access register: each client's outside accounts, who owns them, what access we hold, where
# the login lives and when tokens expire. Never the password or token itself.
module AccountManagement
  class AccessesController < ApplicationController
    allow_staff
    before_action :require_account_manager, only: :destroy
    agent_tool :list_accesses, on: :index, title: "List clients’ outside accounts and our access",
      description: "The access register: pages, ad accounts, pixels, analytics, domains. Each with who owns it, our access, where its login lives, token expiry, when it was last checked and its problems.",
      params: { state: %w[attention all], client_id: "integer" }
    agent_tool :create_access, on: :create, title: "Add an account to a client’s access register",
      description: "Never a password or token: login_location says where it's kept (\"Bitwarden › BioFuse › Meta\"). owner_name is required when owned_by is third_party (a former agency, say).",
      params: { access: { client_id: "integer!", platform: Access::PLATFORMS.keys, name: "string!", external_id: "string", url: "string",
        owned_by: Access::OWNED_BY.keys, owner_name: "string", our_access: Access::OUR_ACCESS.keys, login_location: "string",
        token_expires_on: "date", notes: "text" } }
    agent_tool :update_access, on: :update, title: "Change an account in the access register",
      params: { access: { platform: Access::PLATFORMS.keys, name: "string", external_id: "string", url: "string", owned_by: Access::OWNED_BY.keys,
        owner_name: "string", our_access: Access::OUR_ACCESS.keys, login_location: "string", token_expires_on: "date", notes: "text" } }
    agent_tool :verify_access, on: :verify, title: "Mark an account checked today",
      description: "Someone looked: who owns it, our access and the token expiry are as recorded. Change them first with update_access if not."
    agent_tool :delete_access, on: :destroy, title: "Remove an account from the register"

    before_action :set_access, only: %i[edit update verify destroy]

    def index
      @state = params[:state].presence_in(%w[attention all]) || "all"
      scope = Access.includes(:client, :verified_by).joins(:client).order("clients.name", :platform, :name)
      scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
      @accesses = scope.to_a
      @accesses = @accesses.reject(&:in_order?) if @state == "attention"
    end

    def new
      @access = Access.new(client: ::Client.find_by(id: params[:client_id]), platform: params[:platform].presence_in(Access::PLATFORMS.keys) || "facebook_page")
    end

    def create
      @access = Access.new(access_params)
      @access.client = ::Client.find_by(id: params.dig(:access, :client_id))
      if @access.save
        @access.record_event!("access.added", payload: { platform: @access.platform_label, owned_by: @access.owned_by_label, our_access: @access.our_access_label })
        redirect_to account_management_accesses_path(client_id: @access.client_id), notice: "Added #{@access.name}.#{" #{@access.problems.first}." unless @access.in_order?}"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @access.update(access_params)
        @access.record_event!("access.changed", payload: @access.saved_changes.except("updated_at").transform_values(&:last))
        redirect_to account_management_accesses_path(client_id: @access.client_id), notice: "Saved #{@access.name}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def verify
      @access.verify!
      redirect_back fallback_location: account_management_accesses_path(client_id: @access.client_id), notice: "#{@access.name} checked today.#{" Still: #{@access.problems.first}." unless @access.in_order?}"
    end

    def destroy
      @access.destroy!
      redirect_to account_management_accesses_path(client_id: @access.client_id), notice: "Removed #{@access.name} from the register."
    end

    private
      def set_access = @access = Access.find(params[:id])

      def access_params
        params.expect(access: %i[platform name external_id url owned_by owner_name our_access login_location token_expires_on notes])
      end
  end
end
