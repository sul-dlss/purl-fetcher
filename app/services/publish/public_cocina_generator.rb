# frozen_string_literal: true

module Publish
  # Adds the constituent (virtual object) relationships to the cocina object
  class PublicCocinaGenerator
    # @param [Cocina::Models::DRO, Cocina::Models::Collection] cocina
    def initialize(cocina:)
      @cocina = cocina
    end

    def self.generate(cocina:)
      new(cocina: cocina).generate
    end

    def generate
      related_resources = @cocina.description.relatedResource

      augmented_description = @cocina.description.new(relatedResource: related_resources + constituent_resources)
      @cocina.new(description: augmented_description)
    end

    private

    def constituent_resources
      VirtualObject.for(druid: @cocina.externalIdentifier).map do |virtual_object|
        Cocina::Models::RelatedResource.new(title: [{ value: virtual_object[:title] }],
                                            type: 'part of',
                                            purl: purl_url(virtual_object[:id]),
                                            displayLabel: 'Appears in')
      end
    end

    def purl_url(druid)
      "https://#{Settings.purl.hostname}/#{druid.delete_prefix('druid:')}"
    end
  end
end
