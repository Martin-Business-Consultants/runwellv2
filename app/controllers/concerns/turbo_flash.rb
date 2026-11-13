# A notice or alert as a turbo stream: a toast in runeui's toaster (turbo_stream.ui_toast), the
# same place the flash shows after a redirect, so every message is one mechanism. In a controller
# or a turbo_stream template: `turbo_stream_flash(notice: "Saved.")`. A notice goes by itself;
# an alert stays until closed. A message may be a hash for more than a line of text:
# `{ title:, description:, duration: (ms), action: { label:, url:, method:, params: } }` sends
# that request from a button in the toast (Undo: AnswersInPlace#undo_notice), and
# `action: { label:, href: }` goes to a page. It's also set as the flash for this response, which
# is where AgentResponses reads what happened.
module TurboFlash
  extend ActiveSupport::Concern

  included do
    helper_method :turbo_stream_flash
  end

  private
    def turbo_stream_flash(**messages)
      messages.compact_blank.map do |kind, message|
        options = message.is_a?(Hash) ? message.to_h.deep_symbolize_keys : { title: message.to_s }
        flash.now[kind] = options[:title]
        alert = kind.to_s == "alert"
        turbo_stream.ui_toast(options.delete(:title), **{ type: (alert ? :error : :success), duration: (0 if alert) }.compact.merge(options))
      end.join.html_safe
    end
end
