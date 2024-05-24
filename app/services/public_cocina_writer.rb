class PublicCocinaWriter
  def self.write(public_cocina, output_path: nil)
    output_path ||= File.join(DruidTools::PurlDruid.new(public_cocina.externalIdentifier, Settings.filesystems.purl_root).path, 'cocina.json')
    output_dir = File.dirname(output_path)
    FileUtils.mkdir_p(output_dir) unless File.directory?(output_dir)
    File.write(output_path, public_cocina.to_json)
  end
end
