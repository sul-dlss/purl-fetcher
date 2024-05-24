class PublicXmlWriter
  def self.write(public_cocina, output_path)
    thumbnail_service = ThumbnailService.new(public_cocina)
    generated_xml = Publish::PublicXmlService.new(public_cocina:, thumbnail_service:).to_xml
    File.write(output_path, generated_xml)
  end
end
