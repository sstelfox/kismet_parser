
class WirelessNetwork
  include DataMapper::Resource

  property :id,           Serial

  property :beacon_rate,  Integer
  property :channel,      Integer
  property :cloaked,      Boolean,  default: false
  property :encryption,   String
  property :essid,        String
  property :max_rate,     String
  property :type,         String
  
  property :created_at,   DateTime
  property :updated_at,   DateTime

  belongs_to :bssid

  has n, :card_sources, through: :seen_networks
  has n, :client_connections
  has n, :seen_networks
  has n, :wireless_clients, through: :client_connections
end

