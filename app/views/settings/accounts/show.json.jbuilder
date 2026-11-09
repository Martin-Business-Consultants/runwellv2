person = @user.person
menu = nav_menu_items
json.summary "Text size: #{@user.text_size ? Setting::TEXT_SIZES[@user.text_size] : "the install's default"}. " \
  "Your menu shows #{menu.reject { person.nav_plugin_hidden?(it.first) }.map(&:second).to_sentence.presence || "no plugins"}."
json.text_size @user.text_size
json.two_factor person.two_factor?
json.passwordless person.passwordless?
json.menu menu do |key, label, _icon|
  json.key key
  json.name label
  json.shown !person.nav_plugin_hidden?(key)
end
