class PurlUpdatesConsumer < Racecar::Consumer
  subscribes_to "purl-updates"

  # Update the Purl database record with Cocina data passed in the message
  def process(message)
    json = JSON.parse(message.value)
    Honeybadger.context({ json_keys: json.keys })
    cocina_object = Cocina::Models.build(json['cocina'])
    actions = json['actions']
    purl = Purl.find_by!(druid: cocina_object.externalIdentifier)
    PurlCocinaUpdater.new(purl, cocina_object, actions).update

    purl.produce_indexer_log_message
  rescue StandardError => e
    Honeybadger.notify(e)
    raise e
  end
end
