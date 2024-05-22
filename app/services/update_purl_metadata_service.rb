class UpdatePurlMetadataService
  attr_reader :cocina_object

  def initialize(cocina_object)
    @cocina_object = cocina_object
  end

  # Write the cocina object to the Purl druid path as cocina.json
  def write
    FileUtils.mkdir_p(purl_druid_path) unless File.directory?(purl_druid_path)

    write_public_cocina
    write_public_xml
    write_kafka_message
  end

  def write_kafka_message
    Racecar.produce_sync(value: { cocina: cocina_object, actions: nil }.to_json, key: druid, topic: "purl-updates")
  end

  def write_public_cocina
    File.write(File.join(purl_druid_path, 'cocina.json'), cocina_object.to_json)
  end

  def write_public_xml
    File.write(File.join(purl_druid_path, 'public.xml'), public_xml)
  end

  # return [String] the Purl path for the cocina object
  def purl_druid_path
    DruidTools::PurlDruid.new(@cocina_object.externalIdentifier, Settings.filesystems.purl_root).path
  end

  def public_xml
    Publish::PublicXmlService.new(public_cocina: cocina_object, thumbnail_service: ThumbnailService.new(cocina_object)).to_xml
  end

  def druid
    cocina_object.externalIdentifier
  end
end
