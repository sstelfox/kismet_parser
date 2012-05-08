
require 'nokogiri'
require 'xmlsimple'
require 'json'
require 'pry'

INPUT_DIR="./input"

namespace :kismet do
  desc "Parses all .netxml and .gpsxml files in the input directory"
  task :parse => [:parse_net, :parse_gps]
  
  desc "Parses all .netxml and .gpsxml files in the input directory, but uses the sloppy netxml parser."
  task :parse_slop => [:parse_net_slop, :parse_gps]
  
  desc "Parses all .netxml files in the input directory"
  task :parse_net => [DB_FILE] do
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
  task :parse_net_slop => [DB_FILE] do
    Dir.glob(INPUT_DIR + "/**/*.netxml").each do |file|
      print "Parsing file: #{file}...\t"

      KismetSqlBridge.process_net_data XmlSimple.xml_in file

      print "Done\n"
    end
  end

  desc "Parses all .gpsxml files in the input directory"
  task :parse_gps => [DB_FILE] do
    gpsxml_parser = KismetParser::GPSXMLParser.new
    noko = Nokogiri::XML::SAX::Parser.new(gpsxml_parser)

    Dir.glob(INPUT_DIR + "/**/*.gpsxml").each do |file|
      print "Parsing file: #{file}...\t"

      noko.parse_file file
      KismetSqlBridge.process_gps_points gpsxml_parser.gps_points

      print "Done\n"
    end
  end
  
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

  file DB_FILE do
    Rake::Task[:db_prep].invoke
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
    cs = CardSource.first_or_create({ uuid: card_source["uuid"]}, {
      uuid:       card_source["uuid"],
      source:     card_source["card-source"][0],
      name:       card_source["card-name"][0],
      interface:  card_source["card-interface"][0],
      type:       card_source["card-type"][0],
      hop:        card_source["card-hop"][0] == "true",
      channels:   channel_helper(card_source["card-channels"][0]),
    })
    binding.pry
  end

  def self.channel_helper(channels)
    channels.split(',').map(&:to_i).sort.join(",")
  end
end

