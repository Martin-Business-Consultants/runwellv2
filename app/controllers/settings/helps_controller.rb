# How Runwell works, under Settings but open to all staff: the overview, connecting an AI
# assistant (MCP, the CLI), and using Runwell through one.
class Settings::HelpsController < ApplicationController
  allow_staff
  agent_exempt :show, :mcp, :ai, reason: "the help pages; the MCP server’s instructions and tool descriptions say the same"

  def show
  end

  def mcp
  end

  def ai
  end
end
