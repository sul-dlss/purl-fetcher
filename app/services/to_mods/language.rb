# frozen_string_literal: true

module ToMods
  # Maps languages from cocina to MODS XML
  class Language
    # @params [Nokogiri::XML::Builder] xml
    # @params [Array<Hash>] languages
    def self.write(xml:, languages:)
      new(xml: xml, languages: languages).write
    end

    def initialize(xml:, languages:)
      @xml = xml
      @languages = Array(languages).map { |language| CocinaDisplay::Languages::Language.new(language) }
    end

    def write
      languages.each do |language|
        write_basic(language)
      end
    end

    private

    attr_reader :xml, :languages

    def write_basic(language)
      top_attributes = {
        displayLabel: Query.display_label(language.cocina),
        # NOTE: appliesTo is an array in cocina, but it is an xml attribute (thus single value) in MODS
        objectPart: Query.applies_to_values(language.cocina).first,
        usage: Query.status(language.cocina)
      }.compact
      xml.language top_attributes do
        attributes = term_attributes(language.cocina)

        # Language#to_s would decode a missing value from the code, but MODS only records the cocina value.
        value = Query.value(language.cocina)
        if value
          attributes[:type] = 'text'
          xml.languageTerm value, attributes
        end

        if language.code
          attributes[:type] = 'code'
          xml.languageTerm language.code, attributes
        end

        write_script(language.script) if language.script
      end
    end

    def term_attributes(cocina)
      {
        valueURI: Query.uri(cocina),
        authorityURI: Query.authority_uri(cocina),
        authority: Query.authority(cocina)
      }.compact
    end

    # @param [CocinaDisplay::Languages::Script] script
    def write_script(script)
      attributes = { authority: Query.authority(script.cocina) }.compact

      if (value = Query.value(script.cocina))
        attributes[:type] = 'text'
        xml.scriptTerm value, attributes
      end

      return unless script.code

      attributes[:type] = 'code'
      xml.scriptTerm script.code, attributes
    end
  end
end
