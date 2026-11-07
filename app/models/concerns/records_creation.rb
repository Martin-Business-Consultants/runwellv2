# A record people add says so in its history (client.created, work.created, task.created), the way
# every write of consequence does, whoever added it: a person, an agent, a plugin. An import is
# history rather than news, so it records none.
module RecordsCreation
  extend ActiveSupport::Concern

  included do
    after_create_commit :record_creation
  end

  private
    def record_creation
      record_event!("#{model_name.element}.created") unless Current.source == "import"
    end
end
