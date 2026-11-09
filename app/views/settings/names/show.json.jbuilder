json.summary "What this install calls things"
json.terms(Setting::TERMS.to_h { [ it, { one: term(it.to_sym), other: term(it.to_sym, count: 2) } ] })
json.labels(WorkType.cached.to_h { [ it.key, { one: it.name_one, other: it.name_other, prefix: it.prefix, enabled: !it.archived? } ] })
