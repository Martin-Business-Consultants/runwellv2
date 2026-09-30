class AgreementMailer < ApplicationMailer
  def sent
    @link = params[:link]
    @version = @link.agreement_version
    @engagement = @version.engagement
    @engagement.client.in_time_zone do
      mail to: @link.contact.email, subject: "#{@engagement.title}: #{@version.label.downcase} for your approval"
    end
  end
end
