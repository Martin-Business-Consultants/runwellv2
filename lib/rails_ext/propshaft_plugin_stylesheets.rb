# A Propshaft compiler for plugins' stylesheets, as 6.0 reads them (docs/plugin-contract.md, the
# compatibility layer). Two names plugins wrote against rune_ui's tokens are runeui's now and mean
# what shadcn means: --accent (a quiet hover fill) and --ring (a colour). A plugin's var(--accent)
# meant the brand's colour and its var(--ring) the focus shadow, so as Propshaft serves a
# stylesheet a plugin registered (Runwell::Plugins.stylesheet), those read as --primary and
# --ui-focus-ring. Every other old name is defined from runeui's tokens in runwell/compat.css.
# Goes in 7.0, with the layer: plugins write runeui's names.
class PropshaftPluginStylesheets < Propshaft::Compiler
  RENAMES = { "accent" => "primary", "ring" => "ui-focus-ring" }.freeze
  PATTERN = /var\(\s*--(accent|ring)\s*(?=[,)])/

  def compile(asset, input)
    return input unless plugin?(asset)

    input.gsub(PATTERN) { "var(--#{RENAMES.fetch($1)}" }
  end

  private
    def plugin?(asset)
      Runwell::Plugins.stylesheets.values.flatten.include?(asset.logical_path.to_s.delete_suffix(".css"))
    end
end

Rails.application.config.assets.compilers << [ "text/css", PropshaftPluginStylesheets ]
