class PurlUpdatesConsumer < Racecar::Consumer
  subscribes_to "purl-update"

  # Currently this is a no-op until we are able to set up a systemd script to run racecar
  def process(_message)
    # json = JSON.parse(message.value)}
    # purl = Purl.find_or_create_by(druid: json.fetch('druid'))
    # PurlXmlUpdater.new(purl).update
  end
end
