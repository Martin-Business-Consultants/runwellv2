# Settings > Appearance > Copy brief for AI: ThemeBrief as text to paste into any AI, or as JSON
# for an agent about to call update_appearance with custom_css.
class Settings::ThemeBriefsController < Settings::BaseController
  agent_tool :theme_brief, on: :show, title: "Get the brief for writing a theme",
    description: "The theming guide (design tokens, rules, an example) with this install's appearance and custom CSS. Write a theme from it, then apply it with update_appearance (custom_css)."

  def show
    @brief = ThemeBrief.new.to_s
    respond_to do |format|
      format.text { render plain: @brief }
      format.json
    end
  end
end
