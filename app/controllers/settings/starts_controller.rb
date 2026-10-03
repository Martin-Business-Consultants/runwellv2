# Settings > Names > Start from: put back one starting setup's words and prices switch
# (Setting::Start), replacing the names chosen so far.
class Settings::StartsController < Settings::BaseController
  agent_tool :apply_starting_setup, on: :update, title: "Use a starting setup's names",
    description: "Replaces every name in Settings > Names (and the prices switch) with a starting setup's: business, team or personal.",
    params: { start: Setting::STARTS.keys }

  def update
    key = params[:start].presence_in(Setting::STARTS.keys)
    return redirect_to(settings_names_path, alert: "Pick business, team or personal.") unless key

    Setting.current.apply_start!(key)
    redirect_to settings_names_path, notice: "Names now start from #{Setting::STARTS[key][:name].downcase}: #{Setting.current.term(:client, count: 2)}, #{Setting.current.term(:engagement, count: 2)}, #{Setting.current.term(:work, count: 2)}."
  end
end
