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
  end

  def write_public_cocina
    PublicCocinaWriter.write(cocina_object, File.join(purl_druid_path, 'cocina.json'))
  end

  def write_public_xml
    PublicXmlWriter.write(cocina_object, File.join(purl_druid_path, 'public'))
  end
end
