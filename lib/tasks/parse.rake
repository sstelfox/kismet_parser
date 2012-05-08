
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
    Rake::Task["kismet:db_prep"].invoke
  end
end

# For handling the conversion between the parsed hashes and the
# database models
class KismetSqlBridge
  def self.process_gps_points(gps_points)
    # TODO:
    # record the bssid with the gps data
    # if the bssid and source are different
    # also record the source with the gps data
  end

  def self.process_net_data(net_data)
    net_data["card-source"].each do |cs|
      self.record_card_source(cs)
    end
    net_data["wireless-network"].each do |wn|
      self.record_wireless_network(wn)
    end
  end

  protected

  def self.channel_helper(channels)
    return channels.split(',').map(&:to_i).sort.join(",")
  end

  def self.encryption_helper(encryption)
    return encryption.sort.join(", ")
  end
  
  def self.record_bssid( bssid, manufacturer = "" )
    return Bssid.first_or_create({ bssid: bssid.downcase },
              { bssid: bssid.downcase, manufacturer: manufacturer })
  end

  def self.record_card_source(card_source)
    return CardSource.first_or_create({ uuid: card_source["uuid"]}, {
      uuid:       card_source["uuid"],
      source:     card_source["card-source"][0],
      name:       card_source["card-name"][0],
      interface:  card_source["card-interface"][0],
      type:       card_source["card-type"][0],
      hop:        card_source["card-hop"][0] == "true",
      channels:   self.channel_helper(card_source["card-channels"][0]),
    })
  end

  def self.record_infrastructure_network(inf_network)
    bssid = self.record_bssid inf_network["BSSID"][0], inf_network["manuf"][0]
    card_source = CardSource.first( uuid: inf_network["seen-card"][0]["seen-uuid"][0] )
    ssids = []

    # A single access point can broadcast multiple SSIDs, I want to record them
    # individually
    unless inf_network["SSID"].nil?
      inf_network["SSID"].each do |ssid|
        ssids << {
          beacon_rate: ssid["beaconrate"],
          bssid: bssid,
          channel: inf_network["channel"][0],
          cloaked: ssid["essid"][0]["cloaked"] == "true",
          encryption: self.encryption_helper(ssid["encryption"]),
          essid: ssid["essid"][0]["content"],
          max_rate: ssid["max-rate"][0],
          type: inf_network["type"],
        }
      end
    else
      ssids << {
          beacon_rate: 0,
          bssid: bssid,
          channel: inf_network["channel"][0],
          cloaked: true,
          encryption: "Unknown", 
          essid: "N/A",
          max_rate: "Unknown",
          type: inf_network["type"],
      }
    end

    clients = []
    inf_network["wireless-client"].each do |client|
      clients << self.record_wireless_client(client)
    end

    return ssids.map do |s|
      wn = WirelessNetwork.first_or_create( {
             channel: s[:channel],
             encryption: s[:encryption],
             essid: s[:essid],
             max_rate: s[:max_rate],
             type: s[:type],
           }, s)

      unless wn.card_sources.include? card_source
        wn.card_sources << card_source
        wn.save
      end

      clients.each do |client|
        unless wn.wireless_clients.include? client
          wn.wireless_clients << client
          wn.save
        end
      end

      wn
    end
  end

  def self.record_probe(probe)
    # Probes only involve one client (the one probing)
    wireless_client = self.record_wireless_client probe["wireless-client"][0]
    card_source = CardSource.first( uuid: probe["seen-card"][0]["seen-uuid"][0] )

    # Essid's aren't always recorded
    begin
      essid = probe["wireless-client"][0]["SSID"][0]["ssid"][0]
    rescue
      essid = ""
    end

    p = Probe.first_or_create( wireless_client: wireless_client, essid: essid )

    unless p.card_sources.include? card_source
      p.card_sources << card_source
      p.save
    end

    return p
  end

  def self.record_wireless_client(wireless_client)
    bssid = self.record_bssid( wireless_client["client-mac"][0], wireless_client["client-manuf"][0] ) 
    card_source = CardSource.first( uuid: wireless_client["seen-card"][0]["seen-uuid"][0] )
    wc = WirelessClient.first_or_create({ bssid: bssid })

    unless wc.card_sources.include? card_source
      wc.card_sources << card_source
      wc.save
    end

    return wc
  end

  def self.record_wireless_network(wireless_network)
    case wireless_network["type"]
    when "probe"
      self.record_probe wireless_network
    when "infrastructure", "data"
      self.record_infrastructure_network wireless_network
    else
      binding.pry
    end
  end

end

