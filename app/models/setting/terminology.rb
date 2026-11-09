# What the install calls things (Settings > Names): the core nouns and each kind of work's names
# and ref prefix, each the install's word if it set one, else the default (terms.en.yml).
module Setting::Terminology
  extend ActiveSupport::Concern

  TERMS = %w[client work scope_item task].freeze

  def term(key, count: 1)
    form = count == 1 ? "one" : "other"
    terminology.dig(key.to_s, form).presence || I18n.t("terms.#{key}.#{form}")
  end

  # Each kind of work's names, prefix and whether it's offered are its WorkType's (Settings >
  # Names > Types). A key no type has (a plugin's stale value) reads as its words.
  def label_name(label, count: 1)
    WorkType.named(label)&.name(count: count) || label.to_s.humanize.then { count == 1 ? it : it.pluralize }
  end

  def label_prefix(label)
    WorkType.named(label)&.prefix
  end

  def label_enabled?(label)
    WorkType.named(label)&.archived? == false
  end

  def enabled_labels
    WorkType.active_keys
  end
end
