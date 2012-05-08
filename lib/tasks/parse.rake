
require 'nokogiri'
require 'xmlsimple'
require 'fileutils'
require 'json'
require 'pry'

INPUT_DIR="../kismet_logs"

namespace :kismet do
  desc "Parses all .netxml and .gpsxml files in the input directory"
  task :parse => [:parse_net, :parse_gps]
  
  task :parse_proper => [:parse_net_proper, :parse_gps]
  
  desc "Parses all .netxml files in the input directory"
  task :parse_net_proper => [DB_FILE] do
    netxml_parser = KismetParser::NetXMLParser.new
    noko = Nokogiri::XML::SAX::Parser.new(netxml_parser)

    Dir.glob(INPUT_DIR + "/**/*.netxml").each do |file|
      print "Parsing file: #{file}...\t"

      noko.parse_file file
      # Do something with the output eventually, it's not good enough right now
      netxml_parser.detection_run

      print "Done\n"

      new_path = file + ".parsed"
      FileUtils.mv(file, new_path)
      puts "Moved file to #{new_path}"
    end
  end

  desc "Sloppily parses all .netxml files in the input directory, this gets a more accurate hash at the expense of loading the whole file into memory"
  task :parse_net => [DB_FILE] do
    Dir.glob(INPUT_DIR + "/**/*.netxml").each do |file|
      print "Parsing file: #{file}...\t"

      KismetParser::DatabaseAdapter.process_net_data XmlSimple.xml_in file

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
      KismetParser::DatabaseAdapter.process_gps_points gpsxml_parser.gps_points

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

