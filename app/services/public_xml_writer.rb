class PublicXmlWriter
  def self.generate(public_cocina)
    thumbnail_service = ThumbnailService.new(public_cocina)
    Publish::PublicXmlService.new(public_cocina:, thumbnail_service:).to_xml
  end
end
