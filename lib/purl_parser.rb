# class used to represent a purl, used to parse information
class PurlParser
  attr_reader :druid

  def initialize(druid)
    @druid = druid
  end

  def public_xml
    @public_xml ||= Nokogiri::XML((Pathname(path) + 'public').open)
  rescue => e
    Honeybadger.notify(e)
    UpdatingLogger.error("For #{path} could not read public XML.  #{e.message}")
  end

  def exists?
    public_xml.present?
  end

  # Extract the release information from public_xml (load the public XML first)
  #
  # @return [Hash] A hash of all trues and falses in the form of {:true => ['Target1', 'Target2'], :false => ['Target3', 'Target4']}
  #
  def releases
    releases = { true: [], false: [] }
    nodes = public_xml.xpath('//publicObject/releaseData/release')
    nodes.each do |node|
      target = node.attribute('to').text
      status = node.text
      releases[status.downcase.to_sym] << target
    end
    releases
  end

  # Extract the druid from publicXML identityMetadata.
  #
  # @return [String] The druid in the form of druid:pid
  #
  def canonical_druid
    public_xml.at_xpath('//publicObject').attr('id')
  end

  # Extract the title from publicXML DC. If there are more than 1 elements, it takes the first.
  #
  # @return [String] The title of the object
  #
  def title
    public_xml.xpath('//*[name()="dc:title"][1]').text
  end

  # Extract the object type
  #
  # @return [String] The object types, if multiple, separated by pipes
  #
  def object_type
    public_xml.xpath('//identityMetadata/objectType').map(&:text).join('|')
  end

  # Extract collections the item is a member of
  #
  # @return [Array] The collections the item is a member of
  #
  def collections
    public_xml.xpath('//*[name()="fedora:isMemberOfCollection"]').map { |n| n.attribute('resource').text.split('/')[1] }
  end

  # Extract collections and sets the item is a member of
  #
  # @return [String] The cat key, an empty string is returned if there is no catkey
  def catkey
    public_xml.xpath("//identityMetadata/otherId[@name='catkey']").text
  end

  ##
  # Returns the publication time, in local time zone.
  # @return [Time]
  def published_at
    Time.parse(public_xml.at_xpath('//publicObject').attr('published').to_s).in_time_zone
  end

  private

  ##
  # Path to the location of public xml document
  # @return [String]
  def path
    DruidTools::PurlDruid.new(
      druid,
      Settings.PURL_DOCUMENT_PATH
    ).path
  end
end
