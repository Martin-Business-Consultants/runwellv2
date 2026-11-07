# What the install calls things (Settings > Names): the core nouns and each kind of work's names
# and ref prefix, each the install's word if it set one, else the default (terms.en.yml).
module Setting::Terminology
  extend ActiveSupport::Concern

  TERMS = %w[client work scope_item task].freeze

  def term(key, count: 1)
    form = count == 1 ? "one" : "other"
    terminology.dig(key.to_s, form).presence || I18n.t("terms.#{key}.#{form}")
  end

  def label_name(label, count: 1)
    form = count == 1 ? "one" : "other"
    terminology.dig("labels", label.to_s, form).presence || I18n.t("terms.labels.#{label}.#{form}")
  end

  def label_prefix(label)
    terminology.dig("labels", label.to_s, "prefix").presence&.upcase || I18n.t("terms.labels.#{label}.prefix")
  end

  def label_enabled?(label)
    terminology.dig("labels", label.to_s, "enabled") != false
  end

  def enabled_labels
    Work::LABELS.select { label_enabled?(it) }
  end
end
