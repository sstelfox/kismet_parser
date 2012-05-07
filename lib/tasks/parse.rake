
require 'nokogiri'
require 'json'

INPUT_DIR="./input"

namespace :kismet do
  desc "Parses all .netxml and .gpsxml files in the input directory"
  task :parse => [:parse_net, :parse_gps]
  
  desc "Parses all .netxml files in the input directory"
  task :parse_net do
    netxml_parser = KismetParser::NetXMLParser.new
    noko = Nokogiri::XML::SAX::Parser.new(netxml_parser)

    Dir.glob(INPUT_DIR + "/**/*.netxml").each do |file|
      print "Parsing file: #{file}...\t"

      noko.parse_file file
      # Do something with this:
      netxml_parser.detection_run

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
      # Do something with this:
      gpsxml_parser.gps_points

      print "Done\n"
    end
  end
end

class KismetSqlBridge
end
