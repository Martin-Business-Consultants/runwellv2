# Runs what plugins that are on registered with Runwell::Plugins.nightly. One plugin failing
# doesn't stop the others.
class PluginsNightlyJob < ApplicationJob
  def perform
    Runwell::Plugins.enabled_nightly_tasks.each do |key, task|
      task.call
    rescue => error
      Rails.error.report(error, context: { plugin: key })
    end
  end
end
