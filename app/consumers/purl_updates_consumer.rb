class PurlUpdatesConsumer < Racecar::Consumer
  subscribes_to "purl-update"

  # Update the Purl database record with Cocina data passed in the message
  def process(message)
    json = JSON.parse(message.value)
    cocina_object = Cocina::Models.build(json)
    purl = Purl.find_by!(druid: cocina_object.externalIdentifier)
    PurlCocinaUpdater.new(purl, cocina_object).update

    produce(purl.as_public_json.to_json,
            key: cocina_object.externalIdentifier,
            topic: Settings.indexer_topic)
    deliver!
  end
end