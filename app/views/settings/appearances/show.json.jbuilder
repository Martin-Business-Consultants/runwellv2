json.summary "Theme #{@setting.theme}, #{@setting.scheme} colors, #{@setting.radius} corners, #{@setting.font} font"
json.extract! @setting, :theme, :scheme, :radius, :font
json.logo @setting.logo.attached?
json.favicon @setting.favicon.attached?
json.choices({ theme: Setting::THEMES.keys, scheme: Setting::SCHEMES.keys, radius: Setting::RADII.keys, font: Setting::FONTS.keys })
