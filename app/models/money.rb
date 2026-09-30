# Money is integer cents. Text like "1,500" or "1500.50" comes in from forms.
module Money
  def self.to_cents(text)
    return 0 if text.blank?

    (BigDecimal(text.to_s.delete(",$ ")) * 100).round.to_i
  rescue ArgumentError
    0
  end

  def self.format(cents)
    "$" + (cents.to_i / 100.0).round(2).to_s.then { |s| s.include?(".") ? s : "#{s}.00" }
                                       .then { |s| s.sub(/\.(\d)$/, '.\10') }
                                       .gsub(/\B(?=(\d{3})+(?!\d))/, ",")
  end
end
