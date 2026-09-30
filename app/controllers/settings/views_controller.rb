class Settings::ViewsController < Settings::BaseController
  agent_tool :show_views, on: :show, title: "Show how lists open"
  agent_tool :update_views, on: :update, title: "Set how lists open", params: { index_view: Setting::INDEX_VIEWS }

  def show
    @setting = Setting.current
  end

  def update
    Setting.current.update!(index_view: params.expect(:index_view))
    redirect_to settings_views_path, notice: "Lists now open as #{Setting.current.index_view}."
  end
end
