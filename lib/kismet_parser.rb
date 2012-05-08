require "kismet_parser/version"
require "kismet_parser/gps_xml_parser"
require "kismet_parser/net_xml_parser"

require 'data_mapper'

DB_FILE=File.expand_path(File.dirname(__FILE__) + '/../db/kismet_runs.db')

# Setup the database!
DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, "sqlite://#{DB_FILE}")
Dir.glob(File.dirname(__FILE__) + '/models/*.rb').each { |f| require f }
DataMapper.finalize

module KismetParser
end
