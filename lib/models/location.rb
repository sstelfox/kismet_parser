
class Location
  include DataMapper::Resource

  property :id,           Serial

  property :altitude,     String,   required: true
  property :latitude,     String,   required: true
  property :longitude,    String,   required: true
  
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :bssid
end

