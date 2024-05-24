class UpdatePurlMetadataService
  # Write the cocina object to the Purl druid path as cocina.json
  def self.write!(cocina_object)
    PublicCocinaWriter.write(cocina_object)
    PublicXmlWriter.write(cocina_object)
    Racecar.produce_sync(value: { cocina: cocina_object, actions: nil }.to_json, key: cocina_object.externalIdentifier, topic: "purl-updates")
  end
end
