
class Probe
  include DataMapper::Resource
  
  property :id,         Serial

  property :essid,      String

  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :wireless_client
end

