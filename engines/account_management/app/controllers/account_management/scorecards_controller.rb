# One lead's scorecard: each measure against its target, and every record that missed.
module AccountManagement
  class ScorecardsController < ApplicationController
    allow_staff
    agent_tool :show_scorecard, on: :show, title: "Show a lead’s account scorecard",
      description: "id: the person's user id. Each measure (agendas a day ahead, recaps within a day, commitments kept, weekly updates by Friday) with its target and the records that missed, their clients, overdue commitments and accounts needing attention. days: the window, 30 by default.",
      params: { days: "integer" }

    def show
      @user = ::User.people.find(params[:id])
      return redirect_to(account_management_scorecard_path(Current.user), alert: "You can see your own scorecard.") unless @user == Current.user || Current.user.can?(:view_scorecards)

      @scorecard = Scorecard.new(@user, days: params[:days].present? ? params[:days].to_i.clamp(7, 365) : 30)
    end
  end
end
