# Every form builds its selects as comboboxes (ComboboxFormBuilder, the choices controller).
Rails.application.config.to_prepare do
  ActionView::Base.default_form_builder = ComboboxFormBuilder
end
