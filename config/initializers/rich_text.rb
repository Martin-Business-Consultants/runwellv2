# Lexxy writes strikethrough as <s> and underline as <u>, which Rails' sanitizer drops, so they
# showed in the editor but not on the page. Registered after initialization so it runs after
# Lexxy's own addition to the same lists (tables, media, data-language, style).
Rails.application.config.after_initialize do
  ActiveSupport.on_load(:action_text_content) do
    ActionText::ContentHelper.allowed_tags = ActionText::ContentHelper.allowed_tags + %w[ s u ]
  end
end
