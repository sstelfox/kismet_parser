
require 'nokogiri'
require 'xmlsimple'
require 'json'
require 'pry'

INPUT_DIR="./input"

namespace :kismet do
  desc "Parses all .netxml and .gpsxml files in the input directory"
  task :parse => [:parse_net, :parse_gps]
  
  desc "Parses all .netxml and .gpsxml files in the input directory, but uses the sloppy netxml parser."
  task :parse_slop => [:parse_net, :parse_gps]
  
  desc "Parses all .netxml files in the input directory"
  task :parse_net do
    netxml_parser = KismetParser::NetXMLParser.new
    noko = Nokogiri::XML::SAX::Parser.new(netxml_parser)

    Dir.glob(INPUT_DIR + "/**/*.netxml").each do |file|
      print "Parsing file: #{file}...\t"

      noko.parse_file file
      # Do something with the output eventually, it's not good enough right now
      netxml_parser.detection_run

      print "Done\n"
    end
  end

  desc "Sloppily parses all .netxml files in the input directory, this gets a more accurate hash at the expense of loading the whole file into memory"
  task :parse_net_slop do
    Dir.glob(INPUT_DIR + "/**/*.netxml").each do |file|
      print "Parsing file: #{file}...\t"

      KismetSqlBridge.process_net_data XmlSimple.xml_in file

      print "Done\n"
    end
  end

  desc "Parses all .gpsxml files in the input directory"
  task :parse_gps do
    gpsxml_parser = KismetParser::GPSXMLParser.new
    noko = Nokogiri::XML::SAX::Parser.new(gpsxml_parser)

    Dir.glob(INPUT_DIR + "/**/*.gpsxml").each do |file|
      print "Parsing file: #{file}...\t"

      noko.parse_file file
      KismetSqlBridge.process_gps_points gpsxml_parser.gps_points

      print "Done\n"
    end
  end
end

# For handling the conversion between the parsed hashes and the
# database models
class KismetSqlBridge
  def self.process_gps_points(gps_points)
  end

  def self.process_net_data(net_data)
    net_data["card-source"].each do |cs|
      build_card_source(cs)
    end
  end

  def self.build_card_source(card_source)
    cs = CardSource.new(
      uuid:       card_source["uuid"],
      source:     card_source["card-source"][0],
      name:       card_source["card-name"][0],
      interface:  card_source["card-interface"][0],
      type:       card_source["card-type"][0],
      hop:        card_source["card-hop"][0] == "true",
      channels:   channel_helper(card_source["card-channels"][0]),
    )
    binding.pry
  end

  def self.channel_helper(channels)
    channels.split(',').map(&:to_i).sort.join(",")
  end
end

# All of the Models and Database stuff below here
require 'data_mapper'

DB_FILE=File.expand_path('./db/kismet_runs.db')

namespace :kismet do
  desc "Blow away the database and bring it inline with the current models"
  task :db_prep do
    require 'dm-migrations'
    DataMapper.auto_migrate!
  end

  desc "Safely attempt to upgrade tables to the current definitions"
  task :db_migrate do
    require 'dm-migrations'
    DataMapper.auto_upgrade!
  end

  file DB_FILE => :db_prep
end

# Setup the database!
DataMapper::Logger.new($stdout, :debug)
#DataMapper.setup(:default, "sqlite::memory:")
DataMapper.setup(:default, "sqlite://#{DB_FILE}")
#DataMapper.setup(:default, "mysql://user:password@hostname/database")
#DataMapper.setup(:default, "postgres://user:password@hostname/database")

class CardSource
  include DataMapper::Resource

  property :id,         Serial
  property :uuid,       String
  property :source,     String
  property :name,       String
  property :interface,  String
  property :type,       String
  property :hop,        Boolean,  default: true 
  property :channels,   String
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :seen_networks
  has n, :seen_clients
end

class Bssid
  include DataMapper::Resource

  property :id,           Serial
  property :bssid,        String,   required: true
  property :manufacturer, String
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :wireless_networks
  has n, :wireless_clients
  has n, :gps_points
end

class WirelessNetwork
  include DataMapper::Resource

  property :id,         Serial
  property :beaconrate, Integer
  property :max_rate,   String
  property :encryption, String
  property :essid,      String
  property :cloaked,    Boolean,  default: false
  property :channel,    Integer
  
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :bssid
  has n, :client_connections
  has n, :wireless_clients, through: :client_connections
  has n, :seen_networks
end

class WirelessClient
  include DataMapper::Resource

  property :id,         Serial
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :bssid
  has n, :client_connections
  has n, :wireless_networks, through: :client_connections
  has n, :probes
  has n, :seen_clients
end

class SeenNetwork
  include DataMapper::Resource

  property :id,         Serial
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :card_source
  belongs_to :wireless_network
end

class SeenClient
  include DataMapper::Resource

  property :id,         Serial
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :card_source
  belongs_to :wireless_client
end

class ClientConnection
  include DataMapper::Resource

  property :id,         Serial
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :wireless_network
  belongs_to :wireless_client
end

class Probe
  include DataMapper::Resource
  
  property :id,         Serial
  property :essid,      String
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :wireless_client
end

class GpsPoint
  include DataMapper::Resource
  
  property :id,         Serial
  property :latitude,   String, required: true
  property :longitude,  String, required: true
  property :altitude,   String, required: true
  property :signal,     Integer, required: true
  property :noise,      Integer
  property :recorded_at,DateTime
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :bssid
end

DataMapper.finalize

