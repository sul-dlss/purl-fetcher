class UpdatePurlMetadataService
  attr_reader :cocina_object, :purl

  def initialize(cocina_object, purl)
    @cocina_object = cocina_object
    @purl = purl
  end

  # Write the cocina object to the Purl druid path as cocina.json
  def write!(only: %i[cocina xml meta])
    FileUtils.mkdir_p(purl_druid_path) unless File.directory?(purl_druid_path)

    write_public_cocina if only.include?(:cocina)
    write_public_xml if only.include?(:xml)

    if only.include?(:meta)
      write_public_purl_metadata
      purl.produce_indexer_log_message
    end

    write_kafka_message if only.include?(:cocina) || only.include?(:xml)
  end

  def write_kafka_message
    return unless cocina_object

    Racecar.produce_sync(value: { cocina: cocina_object, actions: nil }.to_json, key: druid, topic: "purl-updates")
  end

  def write_public_cocina
    return unless cocina_object

    File.write(File.join(purl_druid_path, 'cocina.json'), cocina_object.to_json)
  end

  def write_public_xml
    return unless cocina_object

    File.write(File.join(purl_druid_path, 'public.xml'), public_xml)
  end

  def write_public_purl_metadata
    File.write(File.join(purl_druid_path, 'meta.json'), public_metadata_json.to_json)
  end

  # return [String] the Purl path for the cocina object
  def purl_druid_path
    DruidTools::PurlDruid.new(druid, Settings.filesystems.purl_root).path
  end

  def public_xml
    Publish::PublicXmlService.new(public_cocina: cocina_object, thumbnail_service: ThumbnailService.new(cocina_object)).to_xml
  end

  delegate :druid, to: :purl

  def public_metadata_json
    purl.as_public_json
  end
end
