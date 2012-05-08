
class WirelessNetwork
  include DataMapper::Resource

  property :id,         Serial

  property :beaconrate, Integer
  property :channel,    Integer,  unique_index: :ssid
  property :cloaked,    Boolean,  default: false
  property :encryption, String,   unique_index: :ssid
  property :essid,      String,   unique_index: :ssid
  property :max_rate,   String,   unique_index: :ssid
  
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :bssid

  has n, :card_sources, through: :seen_networks
  has n, :client_connections
  has n, :seen_networks
  has n, :wireless_clients, through: :client_connections
end

