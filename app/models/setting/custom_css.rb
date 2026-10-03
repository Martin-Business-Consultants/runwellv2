# Settings > Appearance > Custom CSS: a stylesheet loaded after the app's (ThemesController),
# meant to set the design tokens in docs/theming.md. It can't reach outside the install or run
# anything: no imports, no url() but data: URIs, none of the old script hooks.
module Setting::CustomCss
  extend ActiveSupport::Concern

  LIMIT = 100.kilobytes
  FORBIDDEN = {
    /@import/i => "@import",
    /url\(\s*(?!["']?\s*data:)/i => "url() other than a data: URI",
    /expression\s*\(/i => "expression()",
    /javascript\s*:/i => "javascript:",
    /behavior\s*:/i => "behavior",
    /-moz-binding/i => "-moz-binding",
    %r{</} => "</"
  }.freeze

  included do
    normalizes :custom_css, with: ->(css) { css.to_s.strip.presence }
    validate :custom_css_is_safe
  end

  def custom_css_digest = Digest::SHA256.hexdigest(custom_css.to_s)[0, 16]

  private
    def custom_css_is_safe
      return if custom_css.blank?

      errors.add(:custom_css, "is over #{LIMIT / 1.kilobyte} KB") if custom_css.bytesize > LIMIT
      found = FORBIDDEN.filter_map { |pattern, name| name if custom_css.match?(pattern) }
      errors.add(:custom_css, "can't use #{found.to_sentence}") if found.any?
    end
end
