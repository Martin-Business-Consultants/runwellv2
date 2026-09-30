# Settings > Fields: what this install records about clients, engagements and work beyond the
# core. A field's kind is fixed once it has values; archiving hides it and keeps them.
class Settings::FieldsController < Settings::BaseController
  agent_tool :list_custom_fields, on: :index, title: "List custom fields",
    description: "Every field an install added to clients (Client), engagements (Engagement) and work (Todo), with the key to set it by (custom_fields: { key: value } on create/update tools) and its kind."
  agent_tool :create_custom_field, on: :create, title: "Add a custom field",
    description: "kind: #{CustomField::KINDS.join(", ")}. choices (for choice): separated by commas. listed: a column in the index table. client_visible: shown in the client portal (engagements).",
    params: { field: { model_type: CustomField::MODELS, label: "string!", kind: CustomField::KINDS, choices: "string", listed: "boolean", client_visible: "boolean" } }
  agent_tool :update_custom_field, on: :update, title: "Change a custom field",
    description: "Rename it, change its choices, whether it's listed or shown to clients, its position (1 is first), or restore an archived one (archived: false). Its kind and key don't change.",
    params: { field: { label: "string", choices: "string", listed: "boolean", client_visible: "boolean", position: "integer", archived: "boolean" } }
  agent_tool :archive_custom_field, on: :destroy, title: "Archive a custom field",
    description: "Hides it from forms, pages and agents. Its values are kept, and update_custom_field with archived: false brings it back."

  before_action :set_field, only: %i[update destroy]

  def index
    @fields = CustomField.ordered.to_a.group_by(&:model_type)
  end

  def create
    field = CustomField.new(params.expect(field: %i[model_type label kind choices listed client_visible]))
    if field.save
      redirect_to settings_fields_path, notice: "Added #{field.label} to #{model_name(field)}."
    else
      redirect_to settings_fields_path, alert: field.errors.full_messages.to_sentence
    end
  end

  def update
    attributes = params.expect(field: %i[label choices listed client_visible position archived])
    archived = attributes.delete(:archived)
    attributes[:archived_at] = ActiveModel::Type::Boolean.new.cast(archived) ? (@field.archived_at || Time.current) : nil unless archived.nil?
    if @field.update(attributes)
      redirect_to settings_fields_path, notice: "Saved #{@field.label}."
    else
      redirect_to settings_fields_path, alert: @field.errors.full_messages.to_sentence
    end
  end

  def destroy
    @field.update!(archived_at: Time.current)
    redirect_to settings_fields_path, notice: "Archived #{@field.label}. Its values are kept."
  end

  private
    def set_field = @field = CustomField.find(params[:id])

    def model_name(field) = helpers.custom_field_model_name(field.model_type, count: 2).downcase
end
