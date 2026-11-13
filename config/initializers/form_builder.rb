# Every form draws its controls with runeui (RunwellFormBuilder): form.select, form.text_field and
# the rest keep Rails' signatures, in the core and in plugins.
Rails.application.config.to_prepare do
  ActionView::Base.default_form_builder = RunwellFormBuilder
end
