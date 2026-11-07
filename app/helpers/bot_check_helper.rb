module BotCheckHelper
  # The provider's widget and its script, inside a public form, when a bot check is set up
  # (Settings > Email > Bot checks); nothing otherwise.
  def bot_check_tag
    check = BotCheck.new
    return unless check.enabled?

    safe_join([
      tag.div(class: "bot-check #{BotCheck::WIDGET_CLASSES.fetch(check.provider)}", data: { sitekey: Setting.current.bot_check_site_key }),
      javascript_include_tag(BotCheck::SCRIPTS.fetch(check.provider), async: true, defer: true, "data-turbo-track": nil)
    ])
  end
end
