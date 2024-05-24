class PublicXmlWriter
  def self.write(public_cocina, output_path: nil)
    output_path ||= File.join(DruidTools::PurlDruid.new(public_cocina.externalIdentifier, Settings.filesystems.purl_root).path, 'public.xml')
    output_dir = File.dirname(output_path)
    FileUtils.mkdir_p(output_dir) unless File.directory?(output_dir)

    thumbnail_service = ThumbnailService.new(public_cocina)
    generated_xml = Publish::PublicXmlService.new(public_cocina:, thumbnail_service:).to_xml
    File.write(output_path, generated_xml)
  end
end
