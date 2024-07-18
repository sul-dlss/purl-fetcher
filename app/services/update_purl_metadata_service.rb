class UpdatePurlMetadataService
  attr_reader :purl, :version, :versions_path

  delegate :cocina_object, :druid, :purl_druid_path, to: :purl

  def initialize(purl, version: '1')
    @purl = purl
    @version = version
    awfl_directory = DruidTools::Druid.new(druid, Settings.filesystems.stacks_content_addressable).path
    @versions_path = "#{awfl_directory}/versions"
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
    if Settings.features.awfl_metadata
      cocina_path = File.join(versions_path, "cocina.#{version}.json")
      FileUtils.mkdir_p(File.dirname(cocina_path))
      PublicCocinaWriter.write(cocina_object, cocina_path)
      link_as_head(cocina_path, 'cocina.json') # TODO: This may be conditional when we support more versions
    end

    return unless Settings.features.legacy_purl

    PublicCocinaWriter.write(cocina_object, File.join(purl_druid_path, 'cocina.json'))
  end

  # Call this if the file at source_path should be considered the "head" version
  def link_as_head(source_path, filename)
    # create the link to the head version as specified by AWFL (e.g. cocina.json -> cocina.3.json)
    link_path = File.join(versions_path, filename)
    delete_if_exists(link_path)
    File.link(source_path, link_path)
  end

  def unlink_head(filename)
    link_path = File.join(versions_path, filename)
    delete_if_exists(link_path)
  end

  def delete_if_exists(path)
    FileUtils.rm_f(path)
  end

  def write_public_xml
    if Settings.features.awfl_metadata
      xml_path = File.join(versions_path, "public.#{version}.xml")
      PublicXmlWriter.write(cocina_object, xml_path)
      link_as_head(xml_path, 'public') # TODO: This may be conditional when we support more versions
    end
    return unless Settings.features.legacy_purl

    PublicXmlWriter.write(cocina_object, File.join(purl_druid_path, 'public'))
  end

  def delete_public_cocina
    if Settings.features.awfl_metadata
      cocina_path = File.join(versions_path, "cocina.#{version}.json")
      delete_if_exists(cocina_path)
      unlink_head('cocina.json')
      # TODO: Will need to link previous version when we support more versions
    end

    # Cleanup any legacy files
    delete_if_exists(File.join(purl_druid_path, 'cocina.json'))
  end

  def delete_public_xml
    if Settings.features.awfl_metadata
      xml_path = File.join(versions_path, "public.#{version}.xml")
      delete_if_exists(xml_path)
      unlink_head('public')
      # TODO: Will need to link previous version when we support more versions
    end

    # Cleanup any legacy files
    delete_if_exists(File.join(purl_druid_path, 'public'))
  end
end
