require "reporting/engine"

module Reporting
  # Every figure comes from the QuickBooks plugin: its mirror of invoices and payments, and
  # QuickBooks' own profit and loss. Without it switched on there is nothing to report.
  def self.source_ready? = Runwell::Plugins.enabled?(:quickbooks) && defined?(::Quickbooks::Invoice).present?
end
