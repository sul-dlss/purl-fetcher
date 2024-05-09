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
    purl.produce_indexer_log_message

    test_public_xml_generation(cocina_object)
  rescue Cocina::Models::ValidationError => e
    Honeybadger.notify(e, context: { json: })

  rescue StandardError => e
    Honeybadger.notify(e, context: { json: })
    raise e
  end

  # If we don't see any errors from this in a few weeks, we can write this to the filesystem'
  def test_public_xml_generation(public_cocina)
    thumbnail_service = ThumbnailService.new(public_cocina)
    generated_xml = Publish::PublicXmlService.new(public_cocina:, thumbnail_service:).to_xml
    path = "#{DruidTools::PurlDruid.new(public_cocina.externalIdentifier, Settings.filesystems.purl_root).path}/public"
    existing_xml = File.read(path)
    Honeybadger.notify("Generated XML is not equivalent", context: { druid: public_cocina.externalIdentifier }) unless EquivalentXml.equivalent?(generated_xml, existing_xml)
  rescue StandardError => e
    Honeybadger.notify(e, context: { druid: public_cocina.externalIdentifier })
  end
end
