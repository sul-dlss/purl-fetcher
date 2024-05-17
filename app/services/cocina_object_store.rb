class CocinaObjectStore
  def self.find(druid)
    path = "#{purl_druid_path(druid)}/cocina.json"
    data_hash = JSON.parse(File.read(path))
    Cocina::Models.build(data_hash)
  end

  def self.purl_druid_path(druid)
    DruidTools::PurlDruid
      .new(druid, Settings.filesystems.purl_root)
      .path
  end
end
