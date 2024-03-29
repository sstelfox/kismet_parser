
class SeenNetwork
  include DataMapper::Resource

  property :id,         Serial

  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :card_source
  belongs_to :wireless_network
end

