# How the install looks (Settings > Appearance): theme, corners, colour scheme, font and text size,
# plus its logo and favicon.
module Setting::Appearance
  extend ActiveSupport::Concern

  THEMES = { "system" => "System", "light" => "Light", "dark" => "Dark" }.freeze
  RADII = { "sharp" => "Sharp", "fizzy" => "Soft", "round" => "Round" }.freeze
  # "fizzy" is the default (the column's, and what every install that never chose has): shadcn/ui's
  # neutral, a near-black primary. The rest colour the primary.
  SCHEMES = { "fizzy" => "Neutral", "indigo" => "Indigo", "forest" => "Forest", "plum" => "Plum", "ocean" => "Ocean", "graphite" => "Graphite" }.freeze
  # Each scheme's accent as hex (its light oklch in appearance.css, converted), for email, which
  # knows neither oklch nor CSS variables.
  SCHEME_COLORS = { "fizzy" => "#171717", "indigo" => "#4f39f6", "forest" => "#008236", "plum" => "#9810fa", "ocean" => "#007595", "graphite" => "#314158" }.freeze
  # Text size: the page's base size, which every rem in the stylesheets scales from (Default is
  # 16px). Each person may pick their own (User#text_size, Settings > Your account).
  TEXT_SIZES = { "small" => "Small", "default" => "Default", "large" => "Large", "larger" => "Larger" }.freeze
  FONTS = { "system" => "System", "humanist" => "Humanist", "rounded" => "Rounded", "serif" => "Serif", "mono" => "Mono" }.freeze

  included do
    has_one_attached :logo
    has_one_attached :favicon

    validates :theme, inclusion: { in: THEMES.keys }
    validates :radius, inclusion: { in: RADII.keys }
    validates :scheme, inclusion: { in: SCHEMES.keys }
    validates :font, inclusion: { in: FONTS.keys }
    validates :text_size, inclusion: { in: TEXT_SIZES.keys }
  end

  def brand_color = SCHEME_COLORS.fetch(scheme, SCHEME_COLORS["fizzy"])
end
