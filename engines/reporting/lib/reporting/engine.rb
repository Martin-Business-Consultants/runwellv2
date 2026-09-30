module Reporting
  # A Runwell plugin: financial reports for owners and managers, read from what the QuickBooks
  # plugin brings in (billed, collected, receivables, clients, recurring revenue, unbilled
  # agreed work) and from QuickBooks' own profit and loss. It has no tables: every number is
  # one an accountant can find in the books.
  class Engine < ::Rails::Engine
    initializer "reporting.routes" do |app|
      app.routes.append do
        scope "reports", module: "reporting", as: "reporting" do
          resource :report, only: :show, path: ""
        end
      end
    end

    initializer "reporting.helpers" do
      ActiveSupport.on_load(:action_view) { include Reporting::ChartsHelper }
    end

    config.to_prepare do
      Runwell::Plugins.register :reporting, name: "Reporting", version: "0.1.0", author: "Runwell",
        bundled: true, enabled_by_default: false,
        description: "Financial reports from QuickBooks: billed and collected by month, what clients owe and how late, revenue by client, recurring revenue and whether QuickBooks bills all of it, agreed work not yet invoiced, and profit and loss. Needs the QuickBooks plugin."
      Runwell::Plugins.permission :reporting, :view_financials, name: "See financial reports", roles: %w[owner manager]
      Runwell::Plugins.nav :reporting, "Reports", -> { reporting_report_path if can?(:view_financials) }
      Runwell::Plugins.stylesheet :reporting, "reporting/reports"
    end
  end
end
