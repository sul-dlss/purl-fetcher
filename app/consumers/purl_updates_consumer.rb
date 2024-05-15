class PurlUpdatesConsumer < Racecar::Consumer
  subscribes_to "purl-updates"

  # Update the Purl database record with Cocina data passed in the message
  def process(message)
    json = JSON.parse(message.value)

    raise Cocina::Models::ValidationError, 'Missing cocina data' if json['cocina'].blank?

    cocina_object = Cocina::Models.build(json['cocina'])
    actions = json['actions']
    purl = Purl.find_by!(druid: cocina_object.externalIdentifier)
    PurlCocinaUpdater.new(purl, cocina_object, actions).update
  rescue Cocina::Models::ValidationError => e
    Honeybadger.notify(e, context: { json: })
  rescue StandardError => e
    Honeybadger.notify(e, context: { json: })
    raise e
  end
end
