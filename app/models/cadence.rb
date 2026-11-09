# How often something comes round: a recurring piece of work's period (WorkType#cadence,
# Work#cadence) and a repeating task's (Task#repeat). One list, so a type, a piece of work and a
# task always offer the same choices, and one rule for the next date.
module Cadence
  NAMES = { "weekly" => "Weekly", "biweekly" => "Every two weeks", "monthly" => "Monthly", "quarterly" => "Quarterly", "yearly" => "Yearly" }.freeze
  KEYS = NAMES.keys.freeze
  # What one period is called, for a check-in's title ("Monthly check-in") and the meta line.
  PERIODS = { "weekly" => "week", "biweekly" => "two weeks", "monthly" => "month", "quarterly" => "quarter", "yearly" => "year" }.freeze

  module_function

  def name(cadence) = NAMES[cadence.to_s]
  def period(cadence) = PERIODS[cadence.to_s]

  # The pickers' choices: [[name, key]].
  def options = NAMES.map { |key, name| [ name, key ] }

  # `times` periods after date, counted from date itself so the 31st stays the month's last day
  # rather than drifting to the 28th.
  def advance(date, cadence, times = 1)
    case cadence.to_s
    when "weekly" then date + 7 * times
    when "biweekly" then date + 14 * times
    when "monthly" then date >> times
    when "quarterly" then date >> (3 * times)
    when "yearly" then date >> (12 * times)
    else raise ArgumentError, "unknown cadence #{cadence.inspect}"
    end
  end

  # The next date after `from` on this cadence that isn't before `today`: a repeat that was done
  # late skips the periods already gone rather than coming back overdue.
  def next_after(from, cadence, today: Date.current)
    times = 1
    times += 1 while advance(from, cadence, times) < today
    advance(from, cadence, times)
  end
end
