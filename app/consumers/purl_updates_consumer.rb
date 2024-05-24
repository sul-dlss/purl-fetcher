class PurlUpdatesConsumer < Racecar::Consumer
  subscribes_to "purl-updates"

  # Update the Purl database record with Cocina data passed in the message
  def process(message)
    json = JSON.parse(message.value)

    raise Cocina::Models::ValidationError, 'Missing cocina data' if json['cocina'].blank?

    cocina_object = Cocina::Models.build(json['cocina'])
    purl = Purl.find_by!(druid: cocina_object.externalIdentifier)
    PurlCocinaUpdater.new(purl, cocina_object).update

    test_public_xml_generation(cocina_object)
  rescue Cocina::Models::ValidationError => e
    Honeybadger.notify(e, context: { json: })
  rescue StandardError => e
    Honeybadger.notify(e, context: { json: })
    raise e
  end

  # If we don't see any errors from this in a few weeks, we can write this to the filesystem'
  def test_public_xml_generation(public_cocina)
    output_path = Rails.root + "tmp/#{public_cocina.externalIdentifier}-public-generated.xml"
    PublicXmlWriter.write(public_cocina, output_path)
    GeneratedXmlTester.test(output_path, public_cocina.externalIdentifier)
  rescue StandardError => e
    Honeybadger.notify(e, context: { druid: public_cocina.externalIdentifier, output_path: })
  end
end
