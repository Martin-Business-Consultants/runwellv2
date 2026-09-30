class ContactsController < ApplicationController
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :create_contact, on: :create, title: "Add a contact to a client",
    params: { contact: { name: "string!", role: "string", email: "string", phone: "string", portal_access: "boolean", can_approve: "boolean" } },
    confirm: "Giving a contact portal access lets them sign in and see this client’s shared work and documents."
  agent_tool :update_contact, on: :update, title: "Change a contact",
    params: { contact: { name: "string", role: "string", email: "string", phone: "string", portal_access: "boolean", can_approve: "boolean" } },
    confirm: "Portal access and approval rights decide what this person at the client can see and sign off."
  agent_tool :archive_contact, on: :destroy, title: "Archive a contact",
    description: "They drop off the client’s contacts and lose portal access and approval rights. Past approvals and requests stay."

  before_action :set_client, only: %i[new create]
  before_action :set_contact, only: %i[edit update destroy]

  def new
    @contact = @client.contacts.new
  end

  def create
    @contact = @client.contacts.new(contact_params)
    if @contact.save
      redirect_to @client, notice: "Contact added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @contact.update(contact_params)
      redirect_to @contact.client, notice: "Contact updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @contact.archive!
    redirect_to @contact.client, notice: "#{@contact.name} archived."
  end

  private

  def set_client = @client = Client.find(params[:client_id])
  def set_contact = @contact = Contact.active.find(params[:id])
  def contact_params = params.expect(contact: %i[name role email phone portal_access can_approve])
end
