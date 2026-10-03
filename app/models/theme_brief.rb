# What an AI needs to write a theme for this install (Settings > Appearance > Copy brief for AI,
# and the theme_brief tool): docs/theming.md, then the install's own choices and custom CSS.
class ThemeBrief
  def initialize(setting = Setting.current)
    @setting = setting
  end

  def to_s
    <<~MARKDOWN
      You're writing a theme for #{@setting.brand_name == "Runwell" ? "a Runwell install" : "#{@setting.brand_name}'s Runwell install"}: a stylesheet
      that sets Runwell's design tokens. Follow the guide below exactly: tokens first, both light and
      dark, nothing it forbids. Answer with one CSS block and a line on what you chose and why.

      Ask me for the business's name, logo, website or colors if I haven't given them.

      ## This install now

      - Theme: #{Setting::THEMES[@setting.theme]}; colors: #{Setting::SCHEMES[@setting.scheme]}; corners: #{Setting::RADII[@setting.radius]}; font: #{Setting::FONTS[@setting.font]}; text size: #{Setting::TEXT_SIZES[@setting.text_size]}
      - Logo: #{@setting.logo.attached? ? "yes" : "none yet"}

      #{current_css}

      ---

      #{guide}
    MARKDOWN
  end

  private
    def current_css
      return "No custom CSS yet." if @setting.custom_css.blank?

      "Its custom CSS now (change it rather than starting over, unless asked):\n\n```css\n#{@setting.custom_css}\n```"
    end

    def guide = Rails.root.join("docs/theming.md").read
end
