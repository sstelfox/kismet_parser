
class ClientConnection
  include DataMapper::Resource

  property :id,         Serial

  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :wireless_client
  belongs_to :wireless_network
end

