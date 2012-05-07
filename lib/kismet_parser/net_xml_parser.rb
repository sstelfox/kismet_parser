require 'nokogiri'

class KismetParser::NetXMLParser < Nokogiri::XML::SAX::Document

  def start_document
    @detection_run = {
      "wireless-networks" => [],
      "card-sources" => [],
    }
    @wireless_network = nil
    @tag_hierarchy = []

    @active_object = nil
  end

  def start_element(name, attributes = [])
    @tag_hierarchy.push name
    return unless attributes.count > 0

    case name
    when "card-source"
      @active_object = {}
    when "wireless-network"
      @active_object = {}
      @active_object["clients"] = []
    when "wireless-client"
      @wireless_network = @active_object
      @active_object = {}
    end
  end

  def characters(string)
    string.strip!
    return if string.empty?

    attr_name = @tag_hierarchy.last

    if @active_object[attr_name].nil?
      @active_object[attr_name] = string
    elsif @active_object[attr_name].kind_of? Array
      @active_object[attr_name].push string
    else
      @active_object[attr_name] = [@active_object[attr_name], string]
    end
  end

  def end_element(name)
    @tag_hierarchy.pop
    return if name == "card-source" && @tag_hierarchy.include?("card-source")

    case name
    when "card-source"
      @detection_run["card-sources"].push @active_object
      @active_object = {}
    when "wireless-client"
      @wireless_network["clients"].push @active_object
      @active_object = @wireless_network
    when "wireless-network"
      @detection_run["wireless-networks"].push @active_object
      @active_object = {}
    end
  end

  def detection_run
    @detection_run
  end
end

