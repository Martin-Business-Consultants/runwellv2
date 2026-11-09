# After every render, ReActionView sends the page's slot dependency map (which state each slot
# reads), and Herb 0.11 rebuilds it from the templates each time: 30-50ms a page, more than the
# page's own templates take, for the same answer. The map depends only on the template files (the
# render passes no params), so keep each page's until a view changes: once per boot where code
# doesn't reload, and in development until a template's modified time moves on.
module HerbSlotEnvelopeCache
  ENVELOPES = Concurrent::Map.new

  def self.views_version
    return :static unless Rails.application.config.enable_reloading

    view_dirs = [ Rails.root.join("app/views") ] + InstalledPlugins.loaded.values.map { it.join("app/views") }
    view_dirs.flat_map { Dir.glob(it.join("**/*.erb").to_s) }.map { File.mtime(it).to_r }.max
  end

  def envelope(entry_point, params: {})
    return super unless params.empty?

    ENVELOPES.compute_if_absent([ entry_point.to_s, HerbSlotEnvelopeCache.views_version ]) { super }
  end
end

Herb::Engine::Slots::Dependencies.prepend(HerbSlotEnvelopeCache)
