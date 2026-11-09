# Template mode (RecordLayout): a record page's fields laid out as the install arranged them. A
# page renders its zones (record_fields/zone) and, for owners, the arranging bar
# (record_fields/arrange). Fields sit outside the page's <form> and join it by id (form_id), so a
# field can live in either column and still save with it; every field widget respects that.
module RecordLayoutHelper
  def record_layout(kind) = (@record_layouts ||= {})[kind.to_s] ||= Setting.current.layout(kind)

  # A form builder with no <form> of its own, for fields that join a form by id.
  def record_fields_builder(record, scope: nil)
    ComboboxFormBuilder.new(scope || record.model_name.param_key, record, self, {})
  end

  # What a field is called, for its chip while arranging.
  def layout_field_label(layout, key)
    return layout.custom_field(key)&.label || key if layout.custom?(key)

    labels = {
      "name" => "Name", "status" => "Status", "time_zone" => "Time zone", "internal" => "Internal",
      "title" => "Title", "description" => "Description", "client" => term(:client), "label" => "#{term(:work)} type", "shape" => "Runs as", "cadence" => "How often", "repeat" => "Repeats",
      "due" => "Due", "lead" => "Lead", "others" => "Also on it", "home" => "#{term(:scope_item)} or #{term(:client).downcase}",
      "requested_by" => "Requested by", "source" => "Came in by", "client_visible" => "Visible to the client",
      "email_address" => "Email address", "role" => "Role", "email" => "Email", "phone" => "Phone",
      "portal_access" => "Portal access", "can_approve" => "Can approve",
      "overview" => "Overview", "sections" => term(:scope_item, count: 2), "tasks" => term(:task, count: 2),
      "details" => "Details", "documents" => "Documents", "plugins" => "From plugins"
    }
    labels.fetch(key, key.humanize)
  end

  # A card's heading or the line under it, as the install renamed it (RecordLayout#text), else the
  # default. While arranging, an owner edits it in place (record-layout controller); a missing
  # line under a heading is there, hidden, to be written in.
  def layout_text_tag(layout, slot, default, tag: :h2, class: nil)
    text = layout.text(slot, default)
    content_tag(tag, text, class: binding.local_variable_get(:class), hidden: text.blank?,
      data: { layout_text: slot, layout_default: default.to_s, placeholder: tag == :h2 ? "Heading" : "A line under the heading" })
  end

  # The partial that draws a field (an input with a form, its value without).
  def record_field_partial(layout, key)
    layout.custom?(key) ? "record_fields/custom" : "record_fields/#{layout.kind}/#{key}"
  end

  # A portal task row's link: the task opens in the side sheet over the page (side-panel
  # controller, ?task=), read-only (portal/tasks/panel). Built here so its data attributes stay
  # attributes (Herb writes a computed data hash in a template as text).
  def portal_task_link_to(task, &block)
    link_to url_for(request.query_parameters.merge("task" => task.id)), class: "portal-task-link", draggable: "false",
      data: { turbo_frame: "_top", action: "side-panel#open", side_panel_task_param: task.id, side_panel_title_param: task.title, turbo_prefetch: false }, &block
  end
end
