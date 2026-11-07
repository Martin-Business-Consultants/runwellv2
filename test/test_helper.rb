ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    setup { Current.source = "test" }
    # Installs require two-factor sign-in by default; the tests cover the core with it optional,
    # and those about the requirement switch it on themselves.
    setup { Setting.current.update_columns(require_two_factor: false) }

    # One piece of work per section of a fixture engagement, named after it.
    def work_per_section!(engagement)
      engagement.scope_items.map { engagement.todos.create!(title: it.description, scope_item: it) }
    end
  end
end
