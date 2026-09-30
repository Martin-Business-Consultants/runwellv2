class Portal::EngagementsController < Portal::BaseController
  def index
    @engagements = client.engagements.ordered.includes(agreement_versions: [ :approval, :scope_items ])
  end

  def show
    @engagement = client.engagements.find_by_ref!(params[:ref])
    @pending = @engagement.pending_version
  end
end
