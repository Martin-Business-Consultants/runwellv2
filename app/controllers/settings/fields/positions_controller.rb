# A field dragged into a new place on Settings > Fields: it goes before the field it was dropped
# above (before, an id of the same kind of record's fields), or last when it was dropped at the end.
# The page already shows the new order, so the answer is empty.
class Settings::Fields::PositionsController < Settings::BaseController
  agent_exempt :create, reason: "dragging in the browser; update_custom_field sets position"

  def create
    field = CustomField.find(params[:field_id])
    neighbour = CustomField.where(model_type: field.model_type).where.not(id: field.id).find_by(id: params[:before])
    field.update!(position: neighbour ? { before: neighbour.id } : :last)
    head :no_content
  end
end
