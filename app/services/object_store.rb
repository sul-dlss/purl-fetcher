class ObjectStore
  class NotFoundError < StandardError; end

  def initialize(druid:)
    @druid = druid
    prefix = DruidTools::Druid.new(druid, nil).pathname
    @storage = S3Store.new(prefix:)
  end

  def read_versions
    get('versions/versions.json')
  rescue Aws::S3::Errors::NoSuchKey
    raise NotFoundError, "No versions found for #{druid}"
  end

  def write_versions(json:)
    put('versions/versions.json', json)
  end

  def write_meta_json(json:)
    put('versions/meta.json', json)
  end

  def read_meta_json
    io = get('versions/meta.json')
    JSON.parse(io.read)
  rescue Aws::S3::Errors::NoSuchKey
    raise NotFoundError, "No versions found for #{druid}"
  end

  def write_cocina(version:, json:)
    put("versions/cocina.#{version}.json", json)
  end

  def read_cocina(version:)
    io = get("versions/cocina.#{version}.json")
    JSON.parse(io.read)
  rescue Aws::S3::Errors::NoSuchKey
    raise NotFoundError, "No cocina found for #{druid}, #{version}"
  end

  def content_length(md5:)
    info("content/#{md5}").content_length
  rescue Aws::S3::Errors::NotFound
    raise NotFoundError, "Unable to find content for #{md5}"
  end

  def write_public_xml(version:, xml:)
    put("versions/public.#{version}.xml", xml)
  end

  def read_public_xml(version:)
    io = get("versions/public.#{version}.xml")
    io.read
  rescue Aws::S3::Errors::NoSuchKey
    raise NotFoundError, "No public XML found for #{druid}, #{version}"
  end

  def write_content(md5:, file:)
    put("content/#{md5}", file)
  end

  def read_content(md5:, response_target:)
    get("content/#{md5}", response_target:)
  rescue Aws::S3::Errors::NoSuchKey
    raise NotFoundError, "No content found for #{druid}, #{md5}"
  end

  def delete_content(md5:)
    delete("content/#{md5}")
  end

  def content_md5s
    list_objects('content')
  end

  def destroy
    list_objects('').each { |path| delete(path) }
  end

  attr_reader :druid

  delegate :put, :get, :delete, :list_objects, :info, to: :@storage, private: true
end
