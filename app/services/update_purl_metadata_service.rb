class UpdatePurlMetadataService
  attr_reader :purl

  delegate :cocina_object, :druid, :purl_druid_path, to: :purl

  def initialize(purl)
    @purl = purl
  end

  # Write the cocina object to the Purl druid path as cocina.json
  def write!
    FileUtils.mkdir_p(purl_druid_path) unless File.directory?(purl_druid_path)

    write_public_cocina
    write_public_xml
    write_kafka_message
  end

  # This triggers PurlUpdatesConsumer to run asynchronously
  def write_kafka_message
    Racecar.produce_sync(value: { cocina: cocina_object, actions: nil }.to_json, key: druid, topic: "purl-updates")
  end

  def write_public_cocina
    File.write(File.join(purl_druid_path, 'cocina.json'), cocina_object.to_json)
  end

  def write_public_xml
    File.write(File.join(purl_druid_path, 'public.xml'), public_xml)
  end

  def public_xml
    Publish::PublicXmlService.new(public_cocina: cocina_object, thumbnail_service: ThumbnailService.new(cocina_object)).to_xml
  end
end
