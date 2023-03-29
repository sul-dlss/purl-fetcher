class PurlUpdatesConsumer < Racecar::Consumer
  subscribes_to "purl-update"

  # Update the Purl database record with Cocina data passed in the message
  def process(message)
    json = JSON.parse(message.value)
    cocina_object = Cocina::Models.build(json)
    purl = Purl.find_by!(druid: cocina_object.externalIdentifier)
    PurlCocinaUpdater.new(purl, cocina_object).update

    Racecar.produce_sync(value: purl.as_public_json, key: cocina_object.externalIdentifier, topic: Settings.indexer_topic)
  end
end
