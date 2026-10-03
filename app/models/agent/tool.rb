# One agent tool: a controller action an AI harness can call, described for MCP (name, input
# schema, annotations) and run by dispatching the real request inside the app as the caller's
# token, so a tool can't behave differently from its button (Agent::Dispatch).
module Agent
  class Tool
    # The install's own fields (Settings > Fields), by key: list_custom_fields says which exist.
    CUSTOM_FIELDS = { type: "object", additionalProperties: true,
      description: "Custom fields by key, from list_custom_fields: text; money in whole cents; dates YYYY-MM-DD; true/false; a choice’s exact value. A blank removes a value." }.freeze

    attr_reader :controller, :action, :name, :title, :description, :params, :confirm, :route, :follow, :next_tools

    def initialize(controller, action, declaration)
      @controller, @action = controller, action.to_s
      @name, @title, @description, @params = declaration.values_at(:name, :title, :description, :params)
      @confirm, @follow, @next_tools = declaration.values_at(:confirm, :follow, :next_tools)
      @route = find_route(declaration[:route])
    end

    def verb = route.verb.split("|").first
    def read? = verb == "GET"
    def destructive? = verb == "DELETE"
    def path_parameters = route.required_parts.map(&:to_s)

    # The plugin this tool belongs to, if its controller is a plugin's (GoogleAds::… → :google_ads).
    def plugin
      key = controller.module_parents.reverse.drop(1).first&.name&.underscore&.to_sym
      key if key && Runwell::Plugins.manifests.key?(key)
    end

    def permissions = controller.authorization_rules.select { it.applies?(action) }.filter_map(&:permission)

    # A client's tool: one of the portal's actions, run as their contact.
    def portal? = controller <= Portal::BaseController
    def plugin_on? = plugin.nil? || Runwell::Plugins.enabled?(plugin)

    # Offered to this person on staff: a staff tool their role has the permissions for, its plugin on.
    def available_to?(user)
      !portal? && plugin_on? && permissions.all? { user.can?(it) }
    end

    def input_schema
      properties = path_parameters.to_h { [ it, { type: (it.end_with?("id") ? %w[integer string] : "string"), description: path_description(it) } ] }
      required = path_parameters.dup
      params.each do |key, spec|
        properties[key.to_s] = property_schema(key.to_s, spec)
        required << key.to_s if required_spec?(spec)
      end
      properties["confirm"] = { type: "boolean", description: "Set true once you have shown the person the preview and they agreed." } if confirm
      properties["idempotency_key"] = { type: "string", description: "Optional: any unique string for this change. Sent again with the same key (a retry), the tool answers as before instead of doing it twice." } unless read?
      { type: "object", properties: properties, required: required.uniq }
    end

    def annotations
      { read_only_hint: read?, destructive_hint: destructive?, idempotent_hint: read? || verb.in?(%w[PATCH PUT DELETE]), open_world_hint: confirm.present? }
    end

    def full_description
      [ description.presence || title, (confirm && "Reaches the client: #{confirm} Call once to get a preview, then again with confirm: true."),
        (next_tools.any? && "Often next: #{next_tools.join(", ")}.") ].compact_blank.join("\n\n")
    end

    def path_for(arguments)
      route.format(path_parameters.to_h { [ it.to_sym, arguments[it].to_s ] })
    end

    private
      def find_route(path)
        routes = Rails.application.routes.routes.select do |r|
          r.defaults[:controller] == controller.controller_path && r.defaults[:action] == action &&
            (path.nil? || r.path.spec.to_s.delete_suffix("(.:format)") == path)
        end
        routes.min_by { |r| r.verb == "PUT" ? 1 : 0 } or raise ArgumentError, "No route for #{controller.controller_path}##{action}#{" at #{path}" if path}"
      end

      def path_description(part)
        case part
        when "ref", "engagement_ref" then "The engagement's ref, like WO-12 or S-4, or its title"
        when "id" then "The record's id, or its name to look up"
        when "key" then "The plugin's key"
        else "The #{part.delete_suffix("_id").humanize.downcase}’s id, or its name"
        end
      end

      def required_spec?(spec) = spec.is_a?(String) && spec.end_with?("!")

      # An id parameter (client_id, owner_id…) also takes a name, which Agent::Dispatch resolves.
      def property_schema(key, spec)
        return CUSTOM_FIELDS if key == "custom_fields"
        return schema_for(spec) unless Resolver::PARAMS.key?(key) && spec.to_s.delete_suffix("!") == "integer"

        { type: %w[integer string], description: "The #{Resolver::PARAMS[key].underscore.humanize(capitalize: false)}’s id, or its name to look up" }
      end

      def schema_for(spec)
        case spec
        when Hash
          { type: "object", properties: spec.to_h { |k, v| [ k.to_s, property_schema(k.to_s, v) ] }, required: spec.select { |_, v| required_spec?(v) }.keys.map(&:to_s) }.compact_blank
        when Array
          # [ { title: "string!" } ] is a list of objects; [ "a", "b" ] is one of those values.
          spec.size == 1 && spec.first.is_a?(Hash) ? { type: "array", items: schema_for(spec.first) } : { type: "string", enum: spec.map(&:to_s) }
        else
          type = spec.to_s.delete_suffix("!")
          # "integer[]" is a list of integers.
          return { type: "array", items: schema_for(type.delete_suffix("[]")) } if type.end_with?("[]")

          case type
          when "text" then { type: "string", description: "Rich text: HTML (<p>, <strong>, lists) or plain text" }
          when "date" then { type: "string", format: "date", description: "YYYY-MM-DD" }
          when "file" then { type: "object", description: "A file", properties: { filename: { type: "string" }, content_base64: { type: "string" }, content_type: { type: "string" } }, required: %w[filename content_base64] }
          else { type: type }
          end
        end
      end
  end
end
