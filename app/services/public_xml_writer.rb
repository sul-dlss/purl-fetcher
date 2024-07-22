class PublicXmlWriter
  def self.write(public_cocina, output_path)
    File.write(output_path, generate(public_cocina))
  end

  def self.generate(public_cocina)
    thumbnail_service = ThumbnailService.new(public_cocina)
    Publish::PublicXmlService.new(public_cocina:, thumbnail_service:).to_xml
  end
end
