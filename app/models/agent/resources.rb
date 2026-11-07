# Records a harness can attach as context (MCP resources): runwell://works/WO-12,
# runwell://clients/Bloom and the like, read through the matching show tool (so names work and
# the read is logged like any call). Staff have these; a client's agent its own works.
module Agent
  module Resources
    Template = Data.define(:uri_template, :name, :title, :description, :tool, :parameter)

    STAFF = [
      Template.new("runwell://works/{ref}", "work", "Work", "A piece of work by its ref (WO-12) or title: sections, tasks, notes.", "show_work", "ref"),
      Template.new("runwell://clients/{id}", "client", "Client", "A client by id or name: contacts, work, open tasks, notes.", "show_client", "id"),
      Template.new("runwell://tasks/{id}", "task", "Task", "A task by id or title.", "show_task", "id")
    ].freeze

    CLIENT = [
      Template.new("runwell://portal/works/{ref}", "work", "Work", "One of your work by its ref or title.", "portal_work", "ref")
    ].freeze

    def self.templates(set) = set.reject { it.parameter.nil? }.map { MCP::ResourceTemplate.new(uri_template: it.uri_template, name: it.name, title: it.title, description: it.description, mime_type: "application/json") }
    def self.fixed(set) = set.select { it.parameter.nil? }.map { MCP::Resource.new(uri: it.uri_template, name: it.name, title: it.title, description: it.description, mime_type: "application/json") }

    # The tool and arguments a runwell:// URI stands for, among the set offered.
    def self.call_for(set, uri)
      set.each do |template|
        prefix, suffix = template.uri_template.split(/\{\w+\}/, 2)
        next unless uri.start_with?(prefix) && (template.parameter.nil? ? uri == template.uri_template : uri.end_with?(suffix.to_s))

        value = template.parameter && CGI.unescape(uri.delete_prefix(prefix).delete_suffix(suffix.to_s))
        return [ template.tool, template.parameter ? { template.parameter => value } : {} ]
      end
      nil
    end
  end
end
