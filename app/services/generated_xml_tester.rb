class GeneratedXmlTester
  def self.test(output_path, druid)
    generated_ng = File.open(output_path) { |f| Nokogiri::XML(f) }
    path = DruidTools::PurlDruid.new(druid, Settings.filesystems.purl_root).path
    existing_xml_path = "#{path}/public"
    existing_ng = File.open(existing_xml_path) { |f| Nokogiri::XML(f) }
    generated_ng.root['published'] = existing_ng.root['published'] # Ensure dates align for diff
    return if EquivalentXml.equivalent?(generated_ng, existing_ng)

    delta = `diff #{output_path} #{existing_xml_path}`
    Honeybadger.notify("Generated XML is not equivalent", context: { druid:, delta: })
  end
end
