# ReActionView works out which state each page depends on after every render, and Herb 0.11's
# analysis re-reads and re-parses the page and every partial it reaches each time: about 175
# parses and 350ms on a piece of work page, for the same answer. An analysis depends only on the
# file, so keep each one until the file changes.
module HerbAnalysisCache
  def analyze(file_path)
    path = Pathname.new(file_path).absolute? ? file_path.to_s : @project_path.join(file_path).to_s
    stat = File.stat(path)
    key = [ path, stat.mtime.to_r, stat.size ]
    (@analyses ||= {})[path]&.then { |cached_key, analysis| return analysis if cached_key == key }

    super.tap { @analyses[path] = [ key, it ] }
  end
end

Herb::Analysis::TemplateDependencies.prepend(HerbAnalysisCache)
