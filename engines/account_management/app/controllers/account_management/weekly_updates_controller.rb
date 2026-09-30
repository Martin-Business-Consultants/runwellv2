# Weekly updates: each lead's written report, per client, due by the end of Friday.
module AccountManagement
  class WeeklyUpdatesController < ApplicationController
    allow_staff
    agent_tool :list_weekly_updates, on: :index, title: "List weekly updates",
      description: "Yours, or everyone's if you may see scorecards. Each with its week, whether it was sent and on time.",
      params: { user_id: "integer" }
    agent_tool :show_weekly_update, on: :show, title: "Show a weekly update"
    agent_tool :create_weekly_update, on: :create, title: "Start this week’s update",
      description: "Leave body out to start from the draft built from the week's records (meetings, work shipped, commitments, accounts), then finish it with update_weekly_update and send it with send_weekly_update. week_of: a Monday, this week by default.",
      params: { weekly_update: { week_of: "date", body: "text" } }, next_tools: %i[update_weekly_update send_weekly_update]
    agent_tool :update_weekly_update, on: :update, title: "Change a weekly update before it’s sent",
      params: { weekly_update: { body: "text" } }
    agent_tool :send_weekly_update, on: :submit, title: "Send a weekly update", description: "Final once sent. Due by the end of Friday."

    before_action :set_update, only: %i[show edit update submit]
    before_action :require_author, only: %i[edit update submit]

    def index
      @user = ::User.people.find_by(id: params[:user_id]) if Current.user.can?(:view_scorecards)
      scope = WeeklyUpdate.includes(:user).recent
      scope = Current.user.can?(:view_scorecards) ? (@user ? scope.where(user: @user) : scope.sent.or(scope.where(user: Current.user))) : scope.where(user: Current.user)
      @updates = paginate scope
      @this_week = Current.user.weekly_updates.find_by(week_of: WeeklyUpdate.week_of)
    end

    def show
    end

    def new
      week = WeeklyUpdate.week_of(params[:week_of].present? ? Date.parse(params[:week_of]) : Date.current)
      existing = Current.user.weekly_updates.find_by(week_of: week)
      return redirect_to(existing.sent? ? account_management_weekly_update_path(existing) : edit_account_management_weekly_update_path(existing)) if existing

      @update = Current.user.weekly_updates.new(week_of: week)
      @update.body = @update.draft_body
    rescue Date::Error
      redirect_to account_management_weekly_updates_path, alert: "That isn’t a date."
    end

    def create
      attributes = params.fetch(:weekly_update, {}).permit(:week_of, :body)
      @update = Current.user.weekly_updates.new(week_of: WeeklyUpdate.week_of(attributes[:week_of].present? ? Date.parse(attributes[:week_of]) : Date.current))
      @update.body = attributes[:body].presence || @update.draft_body
      if @update.save
        return submit if params[:send] == "1"

        redirect_to edit_account_management_weekly_update_path(@update), notice: "Draft saved. Send it by #{l @update.due_at, format: :short}."
      else
        redirect_to account_management_weekly_updates_path, alert: @update.errors.full_messages.to_sentence
      end
    rescue Date::Error
      redirect_to account_management_weekly_updates_path, alert: "week_of isn’t a date."
    end

    def edit
      redirect_to account_management_weekly_update_path(@update), alert: "It’s sent, so it’s final." if @update.sent?
    end

    def update
      return redirect_to(account_management_weekly_update_path(@update), alert: "It’s sent, so it’s final.") if @update.sent?

      if @update.update(params.expect(weekly_update: %i[body]))
        return submit if params[:send] == "1"

        redirect_to edit_account_management_weekly_update_path(@update), notice: "Draft saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def submit
      @update.send!
      redirect_to account_management_weekly_update_path(@update), notice: "Sent#{", late" unless @update.on_time?}."
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to edit_account_management_weekly_update_path(@update), alert: e.message
    end

    private
      def set_update
        @update = WeeklyUpdate.find(params[:id])
        head :not_found unless @update.user == Current.user || (@update.sent? && Current.user.can?(:view_scorecards))
      end

      def require_author
        redirect_to account_management_weekly_update_path(@update), alert: "Only its author can change or send it." unless @update.user == Current.user
      end
  end
end
