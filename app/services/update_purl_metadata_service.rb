class UpdatePurlMetadataService
  attr_reader :purl, :version, :versions_path

  delegate :cocina_object, :druid, :purl_druid_path, to: :purl

  def initialize(purl, version: '1')
    @purl = purl
    @version = version
    versioned_object_directory = DruidTools::Druid.new(druid, Settings.filesystems.stacks_root).path
    @versions_path = "#{versioned_object_directory}/versions"
  end

  # Write the cocina object to the Purl druid path as cocina.json
  def write!
    FileUtils.mkdir_p(purl_druid_path) unless File.directory?(purl_druid_path)
    write_public_cocina
    write_public_xml
  end

  def delete!
    delete_public_cocina
    delete_public_xml
  end

  private

  def write_public_cocina
    PublicCocinaWriter.write(cocina_object, File.join(purl_druid_path, 'cocina.json'))
  end

  def unlink_head(filename)
    link_path = File.join(versions_path, filename)
    delete_if_exists(link_path)
  end

  def unlink_if_exists(path)
    File.unlink(path) if File.exist?(path) || File.symlink?(path)
  end

  def write_public_xml
    PublicXmlWriter.write(cocina_object, File.join(purl_druid_path, 'public'))
  end

  def delete_public_cocina
    unlink_if_exists(File.join(purl_druid_path, 'cocina.json'))
  end

  def delete_public_xml
    unlink_if_exists(File.join(purl_druid_path, 'public'))
  end
end
