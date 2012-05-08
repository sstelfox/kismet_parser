
class GpsPoint
  include DataMapper::Resource
  
  property :id,           Serial

  property :altitude,     String, required: true
  property :latitude,     String, required: true
  property :longitude,    String, required: true
  property :noise,        Integer
  property :recorded_at,  DateTime
  property :signal,       Integer, required: true

  property :created_at,   DateTime
  property :updated_at,   DateTime

  belongs_to :bssid
end

