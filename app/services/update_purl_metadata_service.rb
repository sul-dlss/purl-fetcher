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

  def write_public_cocina
    if Settings.features.awfl_metadata
      cocina_path = File.join(versions_path, "cocina.#{version}.json")
      FileUtils.mkdir_p(File.dirname(cocina_path))
      PublicCocinaWriter.write(cocina_object, cocina_path)
      link_as_head(cocina_path, 'cocina.json') # TODO: This may be conditional when we support more versions
    else
      PublicCocinaWriter.write(cocina_object, File.join(purl_druid_path, 'cocina.json'))
    end
  end

  # Call this if the file at source_path should be considered the "head" version
  def link_as_head(source_path, filename)
    # create the link to the head version as specified by AWFL (e.g. cocina.json -> cocina.3.json)
    link_path = File.join(versions_path, filename)
    File.unlink(link_path) if File.exist?(link_path) || File.symlink?(link_path)
    File.symlink(source_path, link_path)

    create_link(source_path, filename)
  end

  # Builds a symlink in the legacy purl filesystem to the path in AWFL
  def create_link(source, dest)
    # There should be no need for this check. However we're not seeing the file on the filesystem, so check for now.
    raise "Path doesn't exist: `#{source}'" unless File.exist?(source)

    link_path = File.join(purl_druid_path, dest)
    FileUtils.mkdir_p(File.dirname(link_path))
    File.unlink(link_path) if File.exist?(link_path) || File.symlink?(link_path)
    File.symlink(source, link_path)
  end

  def write_public_xml
    if Settings.features.awfl_metadata
      cocina_path = File.join(versions_path, "public.#{version}.xml")
      PublicXmlWriter.write(cocina_object, cocina_path)
      link_as_head(cocina_path, 'public') # TODO: This may be conditional when we support more versions
    else
      PublicXmlWriter.write(cocina_object, File.join(purl_druid_path, 'public'))
    end
  end
end
