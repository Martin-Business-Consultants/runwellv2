module Quickbooks
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:quickbooks) }

    private
      def set_engagement = @engagement = ::Engagement.find_by_ref!(params[:engagement_ref])
  end
end
