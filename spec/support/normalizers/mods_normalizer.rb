# frozen_string_literal: true

# Normalizes a Fedora MODS document, accounting for differences between Fedora MODS and MODS generated from Cocina.
# these adjustments have been approved by our metadata authority, Arcadia.
class ModsNormalizer
  MODS_NS = Cocina::Models::Mapping::FromMods::Description::DESC_METADATA_NS
  XLINK_NS = Cocina::Models::Mapping::FromMods::Description::XLINK_NS

  # @param [Nokogiri::Document] mods_ng_xml MODS to be normalized
  # @param [String] druid
  # @param [String] label
  # @return [Nokogiri::Document] normalized MODS
  def self.normalize(mods_ng_xml:, druid:, label:)
    new(mods_ng_xml: mods_ng_xml, druid: druid, label: label).normalize
  end

  # @param [Nokogiri::Document] mods_ng_xml MODS to be normalized
  # @param [String] druid
  # @return [Nokogiri::Document] normalized MODS
  def self.normalize_purl(mods_ng_xml:, druid:)
    new(mods_ng_xml: mods_ng_xml, druid: druid).normalize_purl
  end

  # @param [Nokogiri::Document] mods_ng_xml MODS to be normalized
  # @param [String] druid
  # @param [String] label
  # @return [Nokogiri::Document] normalized MODS
  def self.normalize_purl_and_missing_title(mods_ng_xml:, druid:, label:)
    new(mods_ng_xml: mods_ng_xml, druid: druid, label: label).normalize_purl_and_missing_title
  end

  # @param [Nokogiri::Document] mods_ng_xml MODS to be normalized
  # @return [Nokogiri::Document] normalized MODS
  def self.normalize_identifier_type(mods_ng_xml:)
    new(mods_ng_xml: mods_ng_xml, druid: nil).normalize_identifier_type
  end

  def initialize(mods_ng_xml:, druid:, label: nil)
    @ng_xml = mods_ng_xml.root ? mods_ng_xml.dup : blank_ng_xml
    @ng_xml.encoding = 'UTF-8'
    @druid = druid
    @label = label
  end

  def normalize_purl_and_missing_title
    normalize_purl_location
    @ng_xml = Mods::TitleNormalizer.normalize_missing_title(mods_ng_xml: ng_xml, label: label)
    ng_xml
  end

  private

  attr_reader :ng_xml, :druid, :label

  def normalize_purl_location
    normalize_purl_for(ng_xml.root, purl: Cocina::Models::Mapping::Purl.for(druid: druid))
  end

  def normalize_purl_for(base_node, purl: nil)
    purl_nodes(base_node).each do |purl_node|
      purl_node.content = Cocina::Models::Mapping::FromMods::Purl.purl_value(purl_node)
    end

    # If there is a purl, add a url node if there is not already one.
    if purl && purl_nodes(base_node).to_a.none? { |purl_node| purl_node.content == purl }
      new_location = Nokogiri::XML::Node.new('location', Nokogiri::XML(nil))
      new_url = Nokogiri::XML::Node.new('url', Nokogiri::XML(nil))
      new_url.content = purl
      new_location << new_url
      base_node << new_location
    end
    primary_url_node = primary_url_node_for(base_node, purl)
    base_node.xpath('mods:location/mods:url', mods: MODS_NS).each do |url_node|
      if url_node == primary_url_node
        url_node[:usage] = 'primary display'
      elsif url_node[:usage] == 'primary display'
        url_node.delete('usage')
      end
    end
  end

  def purl_nodes(base_node)
    base_node.xpath('mods:location/mods:url', mods: MODS_NS).select { |url_node| ::Cocina::Models::Mapping::Purl.purl?(url_node.text) }
  end

  def primary_url_node_for(base_node, purl)
    primary_purl_nodes, primary_url_nodes = base_node.xpath('mods:location/mods:url[@usage="primary display"]', mods: MODS_NS)
                                                     .partition { |url_node| ::Cocina::Models::Mapping::Purl.purl?(url_node.text) }
    all_purl_nodes = base_node.xpath('mods:location/mods:url', mods: MODS_NS)
                              .select { |url_node| ::Cocina::Models::Mapping::Purl.purl?(url_node.text) }

    this_purl_node = purl ? all_purl_nodes.find { |purl_node| purl_node.content == purl } : nil

    primary_purl_nodes.first || primary_url_nodes.first || this_purl_node || all_purl_nodes.first
  end

  def blank_ng_xml
    Nokogiri::XML(<<~XML
      <mods xmlns="http://www.loc.gov/mods/v3"#{' '}
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"#{' '}
        version="3.6"#{' '}
        xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd" />
    XML
                 )
  end
end
