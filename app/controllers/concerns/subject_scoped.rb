# A note or document goes on the record a form names as "Type:id" (the record param: the quick
# action tray's picker, or the composer on the record's own page): a client, a piece of work, a
# section or a task. Without one the form is refused.
module SubjectScoped
  extend ActiveSupport::Concern

  SUBJECTS = %w[Client Work ScopeItem Task].freeze

  private
    def set_subject
      @subject = QuickAction.locate(params[:record], SUBJECTS) if params[:record].present?
      redirect_back(fallback_location: root_path, alert: "Choose where this goes.") unless @subject
    end
end
