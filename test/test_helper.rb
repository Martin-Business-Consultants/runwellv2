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

    # People at clients are users with the client role (users.yml), read as Contacts.
    def contacts(name) = Contact.find(users(name).id)

    # One piece of work per section of a fixture work, named after it.
    def tasks_per_section!(work)
      work.scope_items.map { work.tasks.create!(title: it.description, scope_item: it) }
    end
  end
end
