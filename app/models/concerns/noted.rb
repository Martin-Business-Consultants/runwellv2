module Noted
  extend ActiveSupport::Concern

  included do
    has_many :notes, as: :subject, dependent: :destroy
  end
end
