module TaskScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_task
  end

  private

  def set_task = @task = Task.find(params[:task_id])
end
