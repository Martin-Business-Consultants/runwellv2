module User::Named
  extend ActiveSupport::Concern

  def first_name
    name.split(/\s/).first
  end

  def initials
    name.scan(/\b\p{L}/).join.upcase
  end
end
