
class Bssid
  include DataMapper::Resource

  property :id,           Serial

  property :bssid,        String,   required: true, unique_index: true
  property :manufacturer, String

  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :gps_points
  has n, :wireless_clients
  has n, :wireless_networks
end

