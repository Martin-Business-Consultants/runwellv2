# Intake > Schedule: who hears what comes into Intake, and when (IntakeShift). Everyone on the
# team sees it; owners and managers change it. Each line saves as it changes, answered in place.
class Intakes::ShiftsController < ApplicationController
  allow_staff only: :index
  require_permission :manage_intake, except: :index

  TIMES = "minutes after midnight in the install's time zone (480 is 08:00), in steps of #{IntakeShift::STEP}"
  SHIFT_PARAMS = { user_id: "integer", mode: IntakeShift::MODES.keys, days: "integer[]", from_minute: "integer", to_minute: "integer", digest_minutes: "integer[]", sources: "string[]" }.freeze

  agent_tool :list_intake_schedule, on: :index, title: "List the Intake schedule",
    description: "Who hears what comes into Intake, and when: each line's person, sources (clients, agents, team), days (0 Sunday … 6 Saturday) and how: instant (told as it comes in between from_minute and to_minute) or digest (a summary of everything waiting at each of digest_minutes). With no lines, every owner and manager hears each client request as it comes in. Something nobody covers waits for the next window to open.",
    next_tools: %i[create_intake_shift update_intake_shift]
  agent_tool :create_intake_shift, on: :create, title: "Add someone to the Intake schedule",
    description: "user_id: someone on the team. mode: instant (told as it comes in, from_minute to to_minute; an end before the start runs overnight) or digest (at each of digest_minutes). Times are #{TIMES}. days: 0 Sunday … 6 Saturday (default Monday to Friday). sources: clients, agents, team (default clients). Defaults: instant, weekdays 08:00–17:00, clients.",
    params: { intake_shift: SHIFT_PARAMS.merge(user_id: "integer!") }
  agent_tool :update_intake_shift, on: :update, title: "Change a line of the Intake schedule",
    description: "Change who, which days, the window or digest times (#{TIMES}), how (instant or digest) or the sources (clients, agents, team) of a line from list_intake_schedule.",
    params: { intake_shift: SHIFT_PARAMS }
  agent_tool :delete_intake_shift, on: :destroy, title: "Take a line off the Intake schedule",
    description: "With no lines left, every owner and manager hears each client request as it comes in again."

  before_action :set_shift, only: %i[update destroy]

  def index
    @shifts = IntakeShift.includes(:user).ordered.to_a
  end

  def create
    @shift = IntakeShift.new(shift_params)
    if @shift.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: [ replace_schedule, turbo_stream_flash(notice: "#{@shift.user.display_name} is on the schedule.") ] }
        format.html { redirect_to intake_shifts_path, notice: "#{@shift.user.display_name} is on the schedule: #{@shift.when_label}." }
      end
    else
      refuse(@shift)
    end
  end

  def update
    if @shift.update(shift_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: [ replace_row, turbo_stream_flash(notice: "Saved.") ] }
        format.html { redirect_to intake_shifts_path, notice: "Saved #{@shift.user.display_name}: #{@shift.when_label}." }
      end
    else
      refuse(@shift)
    end
  end

  def destroy
    @shift.destroy!
    notice = "#{@shift.user.display_name} is off the schedule."
    respond_to do |format|
      format.turbo_stream { render turbo_stream: [ replace_schedule, turbo_stream_flash(notice:) ] }
      format.html { redirect_to intake_shifts_path, notice: }
    end
  end

  private
    def set_shift = @shift = IntakeShift.find(params[:id])

    def shift_params
      params.expect(intake_shift: [ :user_id, :mode, :from_minute, :to_minute, { days: [], digest_minutes: [], sources: [] } ])
    end

    def replace_schedule = turbo_stream.replace("intake_schedule", method: :morph, partial: "intakes/shifts/schedule", locals: { shifts: IntakeShift.includes(:user).ordered.to_a })
    def replace_row = turbo_stream.replace(helpers.dom_id(@shift, :row), method: :morph, partial: "intakes/shifts/shift", locals: { shift: @shift })

    # Refused: the line goes back to what's saved, and the toast says why.
    def refuse(shift)
      alert = shift.errors.full_messages.to_sentence
      respond_to do |format|
        format.turbo_stream do
          shift.restore_attributes
          streams = [ turbo_stream_flash(alert:) ]
          streams.unshift(replace_row) if shift.persisted?
          render turbo_stream: streams, status: :unprocessable_entity
        end
        format.html { redirect_to intake_shifts_path, alert: }
      end
    end
end
