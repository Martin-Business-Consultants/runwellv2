class ApplicationJob < ActiveJob::Base
  # Jobs (mail among them) run in the install's time zone, as requests do.
  around_perform { |_job, block| Time.use_zone(Setting.zone) { block.call } }

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # A record deleted before its job ran (an event, a mention, a webhook delivery) leaves nothing to do.
  discard_on ActiveJob::DeserializationError
end
