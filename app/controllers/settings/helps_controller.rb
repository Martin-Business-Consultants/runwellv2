# How Runwell works. Under Settings, but open to all staff.
class Settings::HelpsController < ApplicationController
  allow_staff
  agent_exempt :show, reason: "the help page; the MCP server’s instructions and tool descriptions say the same"

  def show
  end
end
