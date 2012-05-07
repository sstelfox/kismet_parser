require 'nokogiri'

class KismetParser::GPSXMLParser < Nokogiri::XML::SAX::Document

  def start_document
    @gps_points = []
  end

  def start_element(name, attributes = [])
    if name == "gps-point"
      hashed_attrs = Hash[attributes]

      # Remove empty bssid's and GPS track logs
      if hashed_attrs["bssid"] != "00:00:00:00:00:00" && hashed_attrs["bssid"] != "GP:SD:TR:AC:KL:OG"
        @gps_points.push(hashed_attrs)
      end
    end
  end

  def gps_points
    @gps_points
  end

end
