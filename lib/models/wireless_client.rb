
class WirelessClient
  include DataMapper::Resource

  property :id,         Serial

  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :bssid

  has n, :card_sources, through: :seen_clients
  has n, :client_connections
  has n, :probes
  has n, :seen_clients
  has n, :wireless_networks, through: :client_connections
end

