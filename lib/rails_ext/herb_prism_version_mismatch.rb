# Herb 0.11.2 parses a template's Ruby with the Prism it carries (2.1) and hands it over serialized;
# ReActionView 0.6.1 reads that back with the bundle's prism gem to classify state conditionals.
# The bundle can't have prism 2 while rubocop-ast pins `~> 1.7`, and a mismatched version refuses
# to load ("Invalid serialization"), which failed every page with state (a piece of work's) and the
# slot dependency map on the rest. When the versions differ, parse the same Ruby Herb did, extracted
# with the same options so every byte offset lines up, with the prism the bundle has.
# Drop this once rubocop-ast allows prism 2 and the bundle moves to the version Herb carries.
module HerbPrismVersionMismatch
  def deserialized_prism_node
    super
  rescue RuntimeError => error
    raise unless error.message.start_with?("Invalid serialization") && source

    ruby = Herb.extract_ruby(source, semicolons: true, comments: false, preserve_positions: true)
    Prism.parse(ruby).value
  end
end

Herb::AST::DocumentNode.prepend(HerbPrismVersionMismatch)
