# The one email this plugin sends: an ad account has stopped serving. Goes to the addresses
# in Settings > Google Ads, often a bookkeeper with no Runwell login. The subject names the
# client, not the customer id.
module GoogleAds
  class AlertMailer < ::ApplicationMailer
    def account_stopped(recipient, account)
      @account = account
      @engagements = account.engagements.to_a
      @clients = @engagements.map { it.client.name }.uniq
      @last_month = Spend.for_account(account.customer_id).find_by(month: 1.month.ago.to_date.beginning_of_month)

      mail to: recipient,
        subject: "Ads have stopped for #{@clients.first.presence || account.label}#{" and #{@clients.size - 1} more" if @clients.size > 1}"
    end
  end
end
