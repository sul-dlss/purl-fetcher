class PublicCocinaWriter
  def self.write(public_cocina, output_path)
    File.write(output_path, public_cocina.to_json)
  end
end
