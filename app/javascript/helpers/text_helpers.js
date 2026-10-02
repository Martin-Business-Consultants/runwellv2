export function isMultiLineString(string) {
  return /\r|\n/.test(string)
}

export function normalizeFilteredText(string) {
  return string
    .toLowerCase()
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "") // Remove diacritics
}

export function filterMatches(text, potentialMatch) {
  return normalizeFilteredText(text).includes(normalizeFilteredText(potentialMatch))
}

// A looser match for short lists of names (a combobox): the text contains the query, or the
// query is the words' initials ("sp", Sarah Producer), or its letters appear in order ("srh").
export function fuzzyMatches(text, potentialMatch) {
  const haystack = normalizeFilteredText(text).trim()
  const needle = normalizeFilteredText(potentialMatch).replace(/\s+/g, "")
  if (!needle || haystack.includes(needle)) return true

  const initials = haystack.split(/\s+/).map(word => word[0]).join("")
  if (initials.startsWith(needle)) return true

  let index = 0
  for (const character of haystack) {
    if (character === needle[index]) index++
    if (index === needle.length) return true
  }
  return false
}

export function toSentence(array, options = {}) {
  const defaultConnectors = {
    words_connector: ", ",
    two_words_connector: " and ",
    last_word_connector: ", and "
  }

  const connectors = { ...defaultConnectors, ...options }

  if (array.length === 0) {
    return ""
  }

  if (array.length === 1) {
    return array[0]
  }

  if (array.length === 2) {
    return array.join(connectors.two_words_connector)
  }

  return array.slice(0, -1).join(connectors.words_connector) + connectors.last_word_connector + array[array.length - 1]
}
