# A notice or alert as a turbo stream (Fizzy's TurboFlash): sets it for this response and
# replaces the flash frame, which shows it as a toast. In a controller or a turbo_stream template:
# `turbo_stream_flash(notice: "Saved.")`.
module TurboFlash
  extend ActiveSupport::Concern

  included do
    helper_method :turbo_stream_flash
  end

  private
    def turbo_stream_flash(**messages)
      messages.compact.each { |kind, text| flash.now[kind] = text }
      turbo_stream.replace("flash", partial: "layouts/shared/flash")
    end
end
