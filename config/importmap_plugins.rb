# Each plugin's own JavaScript (see "Plugin JavaScript" in docs/plugin-contract.md), drawn into the
# import map after the core's (config/importmap.rb), and again whenever it's redrawn in development:
#
#   app/javascript/<key>/controllers/*_controller.js  -> Stimulus controllers "<key-with-dashes>--<name>",
#                                                        loaded on every staff page like the core's
#   app/javascript/<key>/**/*.js                       -> modules a plugin imports as "<key>/…"
#
# Pinned under the plugin's key, so a plugin can't replace a core module or another plugin's.
InstalledPlugins.javascript_dirs.each do |key, dir|
  pin_all_from dir, under: key, to: key
  pin_all_from dir.join("controllers"), under: "controllers/#{key}", to: "#{key}/controllers" if dir.join("controllers").directory?
end
