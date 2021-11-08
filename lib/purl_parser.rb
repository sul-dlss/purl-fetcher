# class used to represent a purl, used to parse information
class PurlParser

  attr_reader :path, :public_xml # the public XML as a nokogiri doc (will be nil if the public file was not found)

  # Given a path to a directory that contains a public xml file, read in the full XML and set the public_xml accessor as a nokogiri document
  # @param path [String] The path to the directory that contains the public file
  #
  def initialize(path)
    @path = path
    @public_path = Pathname(path) + 'public'
    begin
      @public_xml ||= Nokogiri::XML(@public_path.open)
    rescue => e
      Honeybadger.notify(e)
      UpdatingLogger.error("For #{path} could not read public XML.  #{e.message}")
    end
  end

  def exists?
    @public_xml
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
end
