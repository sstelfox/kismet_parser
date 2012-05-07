
require 'nokogiri'
require 'xmlsimple'
require 'json'

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
      # Do something with the output:
      netxml_parser.detection_run

      print "Done\n"
    end
  end

  desc "Sloppily parses all .netxml files in the input directory, this gets a more accurate hash at the expense of loading the whole file into memory"
  task :parse_net_slop do
    Dir.glob(INPUT_DIR + "/**/*.netxml").each do |file|
      print "Parsing file: #{file}...\t"

      # Do something with the output:
      XmlSimple.xml_in file

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
      # Do something with the output:
      gpsxml_parser.gps_points

      print "Done\n"
    end
  end
end

# For handling the conversion between the parsed hashes and the
# database models
class KismetSqlBridge
end

# All of the Models and Database stuff below here
require 'data_mapper'

DB_FILE=File.expand_path('./db/kismet_runs.db')
require 'pry'
binding.pry

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
  property :packets,    Integer
  property :hop,        Boolean,  default: true 
  property :channels,   String
  property :created_at, DateTime
  property :updated_at, DateTime
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
  has 1, :card_source
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
  has 1, :card_source
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
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :bssid
end

DataMapper.finalize

