# Rich text: the Lexxy editor (with @mentions and files for staff), showing what it wrote, and
# code snippets coloured the way Lexxy colours code blocks.
module RichTextHelper
  # A Lexxy editor writing HTML straight into a text column. Staff editors carry Fizzy's @
  # prompt and take dropped or pasted files (Active Storage direct uploads); client-facing
  # editors are text only.
  # form: the id of a form the editor sits outside of (a record page's sidebar, template mode); the
  # editor is form-associated, so it joins that form.
  def rich_text_field(form, method, placeholder: nil, staff: false, form_id: nil)
    rich_text_field_tag(form.field_name(method), form.object.try(method), id: form.field_id(method), placeholder: placeholder, staff: staff, form_id: form_id)
  end

  def rich_text_field_tag(name, value, id:, placeholder: nil, staff: false, form_id: nil)
    options = { name: name, id: id, value: editor_content(value), placeholder: placeholder, class: "lexxy-content", form: form_id }
    if staff
      options[:data] = { direct_upload_url: rails_direct_uploads_url, blob_url_template: rails_service_blob_url(":signed_id", ":filename") }
    else
      options[:attachments] = "false"
    end
    content_tag("lexxy-editor", options) { global_mentions_prompt if staff }
  end

  def global_mentions_prompt
    content_tag "lexxy-prompt", "", trigger: "@", src: prompts_users_path, name: "mention"
  end

  # A snippet to read or copy (a command, a request), coloured by Lexxy's highlighter the way
  # code blocks in rich text are. language is a Prism name: bash, json, ruby, javascript.
  def code_block(code, language: "bash", **options)
    tag.pre code, **options, class: class_names("code-block", options[:class]), data: { language: language }
  end

  # Sanitized HTML from a rich text field, with mentions rendered. Older values are plain
  # text, so they keep their line breaks.
  # Rendered rich text depends only on its HTML (mentions and files render the same for everyone),
  # so each is kept in this process's memory, keyed by the HTML's digest, rather than parsed and
  # rendered again on every page (RICH_TEXT_CACHE, a few MB, oldest out first).
  RICH_TEXT_CACHE = ActiveSupport::Cache::MemoryStore.new(size: 16.megabytes)

  def rich_text(html)
    return if html.blank?

    RICH_TEXT_CACHE.fetch(Digest::SHA256.hexdigest(html)) { render_rich_text(html) }
  end

  def render_rich_text(html)
    html = simple_format(html) unless html.include?("<")
    # Always as HTML: during ReActionView's slots request Action Text's own templates would
    # otherwise render in the slots format and come back as data, not markup.
    formats = lookup_context.formats
    lookup_context.formats = [ :html ]
    tag.div render_action_text_content(ActionText::Content.new(html)), class: "lexxy-content"
  ensure
    lookup_context.formats = formats if formats
  end

  private
    # Lexxy needs each attachment's rendered content in the editor value, as its own
    # Action Text tag helper does for rich text records.
    def editor_content(html)
      return html unless html.to_s.include?(ActionText::Attachment.tag_name)

      ActionText::Fragment.wrap(html).replace(ActionText::Attachment.tag_name) do |node|
        if node["url"].blank?
          attachment = ActionText::Attachment.from_node(node)
          node["content"] = render_action_text_attachment(attachment).to_json
          node["content-type"] ||= attachment.content_type
        end
        node
      end.to_html
    end
end
