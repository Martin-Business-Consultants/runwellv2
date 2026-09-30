module Qa
  # Whether what was seen matches what was agreed, for one expectation. Forgiving about
  # formatting and strict about content: spacing and letter case never fail a check, and a phone
  # number matches in any format ("(512) 575-2929", "512.575.2929", "tel:+15125752929"), which is
  # how a wrong number hides.
  module Matcher
    MATCHES = {
      "is" => "is exactly",
      "list" => "is this list, in any order",
      "includes" => "appears on it",
      "excludes" => "never appears on it"
    }.freeze

    # Matches a page can answer on its own, by being fetched.
    PAGE_MATCHES = %w[includes excludes].freeze

    extend self

    # actual: what was seen, e.g. a From address, or a whole page's text for includes/excludes.
    def match?(match, expected, actual)
      case match
      when "list" then list(expected) == list(actual)
      when "includes" then found?(expected, actual)
      when "excludes" then !found?(expected, actual)
      else normalize(expected) == normalize(actual) || (phone?(expected) && phone_digits(expected) == phone_digits(actual))
      end
    end

    # Addresses and other lists: "office@acme-storage.example, owner@acme-storage.example", one per line, or an array.
    def list(value)
      Array(value).flat_map { it.to_s.split(/[,;\n]/) }.map { normalize(it) }.compact_blank.uniq.sort
    end

    def normalize(value) = value.to_s.squish.downcase

    def found?(expected, text)
      return false if text.blank?
      return pattern_for_phone(expected).match?(text) if phone?(expected)

      normalize(text).include?(normalize(expected))
    end

    def phone?(value) = value.to_s.match?(/\A[\s()+.\-\d]+\z/) && digits(value).size.between?(10, 11)
    def digits(value) = value.to_s.gsub(/\D/, "")
    def phone_digits(value) = digits(value).sub(/\A1(?=\d{10}\z)/, "")

    private
      # The digits in order with anything but a digit allowed between them, so the number is
      # found however it's punctuated and never inside a longer number.
      def pattern_for_phone(value)
        numbers = phone_digits(value).chars
        /(?<!\d)(?:\+?1\D{0,3})?#{numbers.join('\D{0,3}')}(?!\d)/
      end
  end
end
