module Coding
  module CodeHelper
    # 90 → "1h 30m", 45 → "45m".
    def code_duration(minutes)
      hours, rest = minutes.to_i.divmod(60)
      [ ("#{hours}h" if hours.positive?), ("#{rest}m" if rest.positive? || hours.zero?) ].compact.join(" ")
    end
  end
end
