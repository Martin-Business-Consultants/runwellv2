# The client's advertising report in their portal. Inherits the portal's sign-in, so it only
# ever reads ad accounts linked to the signed-in contact's own client.
module GoogleAds
  module Portal
    class ReportsController < ::Portal::BaseController
      before_action { head :not_found unless Runwell::Plugins.enabled?(:google_ads) }

      def show
        @links = Link.for_client(client).includes(:account, :engagement).order(:customer_id).to_a.uniq(&:customer_id)
        @link = @links.find { it.customer_id == Client.normalize_customer_id(params[:account]) } || @links.first
        raise ActiveRecord::RecordNotFound unless @link

        @report = Report.new(@link.customer_id, month: Report.parse_month(params[:month]))
      end
    end
  end
end
