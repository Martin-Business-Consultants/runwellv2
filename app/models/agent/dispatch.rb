# Runs one tool call as the real request: the tool's controller action, with the caller's
# bearer token, so permissions, validations, events and notices are exactly the UI's. Params
# go in as Rails would parse them (booleans as the "1"/"0" a checkbox sends, files as uploads).
# A write that succeeds is followed to the page it redirects to, so the answer carries the
# record as it now stands.
#
# Around every call: a paused token is refused, a token over its rate is told to wait
# (Agent::RateLimit), a write sent again with the same idempotency_key answers as the first did
# instead of running twice, and the call is logged (AgentCall) for the person to see.
module Agent
  class Dispatch
    def initialize(tool, arguments, token:, base_url:)
      @tool, @arguments, @token, @base_url = tool, arguments.to_h.deep_stringify_keys, token, base_url
    end

    attr_reader :tool, :arguments

    CONTROL_ARGUMENTS = %w[confirm idempotency_key].freeze

    def call
      started_at = Time.current
      body = catch(:answer) { guarded { run } }
      AgentCall.record!(access_token, tool: tool.name, body: body, started_at: started_at) if access_token
      body
    end

    private
      def access_token = defined?(@access_token) ? @access_token : (@access_token = AccessToken.authenticate(@token))

      def guarded
        if access_token&.paused?
          with_hint({ "status" => "error", "summary" => "This connection is paused." }, "paused")
        elsif RateLimit.exceeded?(access_token)
          retry_after = RateLimit.retry_after
          { "status" => "error", "code" => "rate_limited", "summary" => "Too many calls this minute.", "retry_after" => retry_after,
            "hint" => Errors.hint("rate_limited", tool: tool.name, retry_after: retry_after) }
        else
          yield
        end
      end

      def run
        @arguments = with_names_resolved(arguments)
        return preview if tool.confirm && arguments["confirm"] != true

        key = arguments["idempotency_key"].to_s.presence unless tool.read?
        if key && access_token && (prior = access_token.agent_idempotency_keys.find_by(key: key))
          return prior.response.merge("replayed" => true) if prior.tool == tool.name

          return with_hint({ "status" => "error", "summary" => "That idempotency_key was already used for #{prior.tool}. Use a new key for a new change." }, "usage")
        end

        answer.tap do |body|
          if key && access_token && body["status"] == "ok"
            access_token.agent_idempotency_keys.create!(key: key, tool: tool.name, response: body)
          end
        rescue ActiveRecord::RecordNotUnique
          nil
        end
      end

      def answer
        status, body = perform(tool.verb, tool.path_for(arguments), params_from(arguments.except(*tool.path_parameters, *CONTROL_ARGUMENTS)))
        if body["status"] == "ok" && !tool.read? && tool.follow && (followed = follow(body["path"]))
          body["data"] = followed
        end
        body["status"] ||= status < 400 ? "ok" : "error"
        if body["status"] == "error"
          with_hint(body, body["code"] || Errors.code_for_status(status))
        elsif body["status"] == "ok" && tool.next_tools.any?
          body["next_tools"] = tool.next_tools
          body["next"] = suggestions(body)
        end
        body
      rescue ActionController::UrlGenerationError, ActionController::RoutingError => e
        with_hint({ "status" => "error", "summary" => "Missing or wrong #{tool.path_parameters.join(", ")}: #{e.message.truncate(160)}" }, "usage")
      rescue => e
        Rails.error.report(e, context: { tool: tool.name })
        with_hint({ "status" => "error", "summary" => "Something went wrong running #{tool.name}: #{e.message.truncate(200)}" }, "failed")
      end

      # Names given for ids, resolved (Agent::Resolver): path ids and refs, id parameters anywhere
      # in the params (client_id, owner_id…), and "Type:name" records.
      def with_names_resolved(values)
        values.to_h do |key, value|
          [ key, resolved(key, value, path: tool.path_parameters.include?(key)) ]
        end
      rescue Resolver::Ambiguous => error
        throw_answer({ "status" => "error", "code" => "ambiguous", "summary" => error.message,
          "candidates" => error.candidates.map { Resolver.describe(it) }, "hint" => Errors.hint("ambiguous", tool: tool.name) })
      rescue Resolver::Missing => error
        throw_answer(with_hint({ "status" => "error", "summary" => error.message }, "not_found"))
      end

      def resolved(key, value, path: false)
        case value
        when Hash then value.to_h { |k, v| [ k, resolved(k, v) ] }
        when Array then value.map { resolved(key, it) }
        when String
          return value if value.blank?

          if path && key.in?(%w[ref engagement_ref])
            value.match?(Resolver::REF) ? value : Resolver.resolve("Engagement", value, client: client_scope).ref
          elsif path && key == "id" && (type = tool.controller.controller_path.split("/").last.classify).in?(Resolver.types)
            Resolver.id_for(type, value, client: client_scope)
          elsif (type = Resolver::PARAMS[key]) && (client_scope.nil? || type.in?(%w[Engagement Todo Request]))
            Resolver.id_for(type, value, client: client_scope)
          elsif key == "record" && (match = value.match(/\A(\w+):(.+)\z/)) && match[1].in?(Resolver.types) && !Resolver.id?(match[2])
            "#{match[1]}:#{Resolver.resolve(match[1], match[2], client: client_scope).id}"
          else
            value
          end
        else value
        end
      end

      def throw_answer(body) = throw(:answer, body)

      # A client's agent looks names up within their own client only.
      def client_scope = access_token&.contact&.client

      def with_hint(body, code)
        body["code"] = code
        body["hint"] ||= Errors.hint(code, tool: tool.name)
        body
      end

      # What to run next, as runwell commands with what's known filled in (the ids this call
      # used, or the record it returned) and placeholders for the rest.
      def suggestions(body)
        known = arguments.merge(returned_ids(body))
        tool.next_tools.filter_map do |name|
          nxt = Catalogue.find(name) or next
          schema = nxt.input_schema
          parts = nxt.path_parameters.map { |p| "--#{p} #{known[p] || "<#{p}>"}" }
          parts << "--record #{known["record"] || "<Type:id>"}" if schema[:properties].key?("record")
          required = schema[:properties].select { |key, spec| key != "record" && !nxt.path_parameters.include?(key) && spec.is_a?(Hash) && spec[:type] == "object" && Array(spec[:required]).any? }
          required.each { |key, spec| Array(spec[:required]).each { |field| parts << "--#{key}.#{field} <#{field}>" } }
          { "tool" => name, "title" => nxt.title, "command" => ([ "runwell", name ] + parts).join(" ") }
        end
      end

      # From the answer: the main record's id and "Type:id", for filling in the next command.
      def returned_ids(body)
        record = [ body["data"], body ].compact.flat_map { |h| h.values.grep(Hash) }.find { it["record"] && it["id"] }
        return {} unless record

        { "id" => record["id"], "record" => record["record"], "todo_id" => (record["id"] if record["type"] == "Todo") }.compact
      end

      # Not done yet: what would happen, in words, so the agent can ask the person first.
      def preview
        subjects = [ describe_record(tool.controller.controller_path.split("/").last.classify, arguments["id"]) ] +
          arguments.select { |key, _| key.end_with?("_id") }.map { |key, id| describe_record(key.delete_suffix("_id").classify, id) }
        { "status" => "needs_confirmation",
          "summary" => "Not done yet. #{tool.confirm} Tell the person, and call #{tool.name} again with confirm: true once they agree.",
          "about" => subjects.compact,
          "call_again_with" => arguments.merge("confirm" => true) }
      end

      def describe_record(class_name, id)
        klass = class_name.safe_constantize
        record = klass.find_by(id: id) if id && klass.is_a?(Class) && klass < ApplicationRecord
        record && ApplicationController.helpers.then { |h| h.try(:agent_label, record) } || record&.try(:search_title) || record&.try(:label)
      end

      def follow(path)
        return if path.blank? || path == "/"

        recognized = Rails.application.routes.recognize_path(path, method: :get)
        reader = Catalogue.all.find { it.read? && it.controller.controller_path == recognized[:controller] && it.action == recognized[:action] }
        return unless reader

        status, body = perform("GET", path, {})
        body.except("status") if status == 200
      rescue ActionController::RoutingError
        nil
      end

      def perform(verb, path, params)
        route = Rails.application.routes.recognize_path(path, method: verb.downcase.to_sym)
        controller = "#{route[:controller].camelize}Controller".constantize
        env = Rack::MockRequest.env_for("#{@base_url}#{path}", method: verb,
          "HTTP_AUTHORIZATION" => "Bearer #{@token}", "HTTP_ACCEPT" => verb == "GET" ? "application/json" : "text/html")
        env["action_dispatch.routes"] = Rails.application.routes
        env["action_dispatch.request.path_parameters"] = route
        env[verb == "GET" ? "action_dispatch.request.query_parameters" : "action_dispatch.request.request_parameters"] = params
        env["action_dispatch.request.request_parameters"] ||= {}

        Current.reset
        status, _headers, response = controller.action(route[:action]).call(env)
        body = +""
        response.each { body << it }
        response.close if response.respond_to?(:close)
        [ status, (JSON.parse(body) rescue { "status" => "error", "summary" => "#{tool.name} answered with a page, not JSON (#{status})." }) ]
      end

      def params_from(value)
        case value
        when Hash
          if value.key?("content_base64") && value.key?("filename")
            upload(value)
          else
            value.transform_values { params_from(it) }
          end
        when Array then value.map { params_from(it) }
        when true then "1"
        when false then "0"
        else value
        end
      end

      def upload(file)
        tempfile = Tempfile.new([ "agent-upload", File.extname(file["filename"].to_s) ], binmode: true)
        tempfile.write(Base64.decode64(file["content_base64"].to_s))
        tempfile.rewind
        ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: File.basename(file["filename"].to_s),
          type: file["content_type"].presence || Marcel::MimeType.for(tempfile, name: file["filename"]))
      end
  end
end
