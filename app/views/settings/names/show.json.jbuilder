json.summary "What this install calls things"
json.terms(Setting::TERMS.to_h { [ it, { one: term(it.to_sym), other: term(it.to_sym, count: 2) } ] })
json.labels(Engagement::LABELS.to_h { [ it, { one: label_term(it), other: label_term(it, count: 2), prefix: Setting.current.label_prefix(it), enabled: Setting.current.enabled_labels.include?(it) } ] })
