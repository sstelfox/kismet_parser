
class KismetParser::DatabaseAdapter
  def self.process_gps_points(gps_points)
    gps_points.each do |gp|
      bssid = self.record_bssid gp["bssid"].downcase
      self.record_gps_point(bssid, gp)

      unless gp["bssid"] == gp["source"]
        bssid = self.record_bssid gp["source"].downcase
        self.record_gps_point(bssid, gp)
      end
    end
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

  def self.time_helper(seconds, microseconds)
    return Time.at("#{seconds}.#{microseconds}".to_i)
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

  def self.record_gps_point(bssid, gps_data)
    time = self.time_helper(gps_data["time-sec"], gps_data["time-usec"])

    return gp = GpsPoint.first_or_create({
      altitude: gps_data["alt"],
      bssid: bssid,
      fix: gps_data["fix"],
      latitude: gps_data["lat"],
      longitude: gps_data["lon"],
      noise: gps_data["noise_dbm"],
      recorded_at: time,
      signal: gps_data["signal_dbm"],
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
    when "infrastructure", "data", "ad-hoc"
      self.record_infrastructure_network wireless_network
    else
      binding.pry
    end
  end

end

