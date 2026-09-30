json.summary pluralize(@clients.size, (@status == "all" ? "" : "#{@status} ") + term(:client).downcase)
json.clients @clients, partial: "clients/client", as: :client
