class ApplicationJob < ActiveJob::Base
  # Jobs (mail among them) run in the install's time zone, as requests do.
  around_perform { |_job, block| Time.use_zone(Setting.zone) { block.call } }

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
