# Prosopite tells queries apart with pg_query, a Postgres parser, which can't read SQLite's ?
# placeholders: every fingerprint failed and Prosopite raised the query itself. Postgres's $1 in
# their place reads the same for fingerprinting. (Prosopite runs in development and test only.)
module ProsopiteSqliteFingerprint
  def fingerprint(query) = super(query.gsub(/(?<![\w'"])\?(?![\w'"])/, "$1"))
end

Prosopite.singleton_class.prepend(ProsopiteSqliteFingerprint) if defined?(Prosopite)
