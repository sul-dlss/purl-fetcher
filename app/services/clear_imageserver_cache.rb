class ClearImageserverCache
  def self.call(druid:, cocina_type:, file_names:)
    return unless [Cocina::Models::ObjectType.image, Cocina::Models::ObjectType.book, Cocina::Models::ObjectType.map].include?(cocina_type)

    file_names.each do |filename|
      next unless filename.ends_with?('.jp2')

      identifier = construct_identifier(druid, filename)
      body = { verb: "PurgeItemFromCache", identifier: }.to_json

      response = post_to_server(body)
      Honeybadger.notify("Unable to clear cache", context: { status: response.to_s }) if response.error
    end
  end

  # Produces an identifier of the form: wy/534/zh/7137/SULAIR_rosette.jp2
  def self.construct_identifier(druid, filename)
    stacks_druid_path = DruidTools::PurlDruid.new(druid, nil).pathname.to_s
    "#{stacks_druid_path}/#{filename}"
  end
  private_class_method :construct_identifier

  def self.post_to_server(body)
    url = "#{Settings.image_server.hostname}/tasks"
    HTTPX.with(headers: { "Content-Type" => "application/json" })
         .plugin(:basic_auth).basic_auth(Settings.image_server.user, Settings.image_server.password)
         .post(url, body:)
  end
  private_class_method :post_to_server
end
