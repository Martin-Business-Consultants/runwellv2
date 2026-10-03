# Tells the owner who asked that their export is ready to download.
class ExportMailer < ApplicationMailer
  def ready
    @export = params[:export]
    mail to: @export.user.email_address, subject: "Your Runwell export is ready"
  end
end
