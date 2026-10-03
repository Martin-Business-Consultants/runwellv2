# Every agent tool, gathered from the controllers' declarations (AgentTools), and which of them
# a person is offered: their role must allow it and its plugin must be on.
module Agent
  module Catalogue
    class << self
      def all
        @all ||= begin
          Rails.application.eager_load!
          ::ApplicationController.descendants.flat_map do |controller|
            controller.agent_declarations.filter_map do |action, declaration|
              Tool.new(controller, action, declaration) unless declaration[:exempt]
            end
          end.sort_by(&:name)
        end
      end

      def for(user, read_only: false) = all.select { it.available_to?(user) && (!read_only || it.read?) }
      def withheld_from(user) = all.reject { it.portal? || it.available_to?(user) }

      # A client contact's tools: the portal's, and their plugins' that are on.
      def for_contact(contact, read_only: false) = all.select { it.portal? && it.plugin_on? && (!read_only || it.read?) }
      def find(name) = all.find { it.name == name.to_s }

      def reset! = @all = nil

      # Every action of every staff controller, with its tool or the reason it has none.
      def coverage
        Rails.application.eager_load!
        ::ApplicationController.descendants.reject { it.abstract? || it.name.start_with?("Portal::") || it <= Portal::BaseController }.flat_map do |controller|
          controller.action_methods.sort.map do |action|
            declaration = controller.agent_declaration_for(action) || nil
            [ "#{controller.name}##{action}", declaration.nil? ? "MISSING" : (declaration[:exempt] ? "exempt: #{declaration[:exempt]}" : declaration[:name]) ]
          end
        end
      end
    end
  end
end
