
class CardSource
  include DataMapper::Resource

  property :id,         Serial

  property :channels,   String
  property :hop,        Boolean,  default: true 
  property :interface,  String
  property :name,       String
  property :type,       String
  property :source,     String
  property :uuid,       String,   unique_index: true

  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :seen_clients
  has n, :seen_probes
  has n, :seen_networks
  has n, :wireless_clients, through: :seen_clients
  has n, :probes, through: :seen_probes
  has n, :wireless_networks, through: :seen_networks
end

