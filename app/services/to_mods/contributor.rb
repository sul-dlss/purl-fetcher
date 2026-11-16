# frozen_string_literal: true

module ToMods
  # Maps contributors from cocina to MODS XML
  class Contributor
    # NOTE: contributors in nameTitleGroups are output as part of Title.
    # @params [Nokogiri::XML::Builder] xml
    # @params [Array<Hash>] contributors
    # @params [Array<Hash>] titles
    # @params [IdGenerator] id_generator
    def self.write(xml:, contributors:, titles:, id_generator:)
      new(xml: xml, contributors: contributors, titles: titles, id_generator: id_generator).write
    end

    def initialize(xml:, contributors:, titles:, id_generator:)
      @xml = xml
      @contributors = contributors
      @titles = titles
      @id_generator = id_generator
    end

    # NOTE: contributors in nameTitleGroups are output as part of Title.
    def write
      Array(contributors)
        .reject { |contributor| NameTitleGroup.in_name_title_group?(contributor: contributor, titles: titles) }
        .each { |contributor| NameWriter.write(xml: xml, contributor: contributor, id_generator: id_generator) }
    end

    private

    attr_reader :xml, :contributors, :titles, :id_generator
  end
end
