# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Publish::DublinCoreService do
  subject(:service) { described_class.new(desc_md_xml) }

  let(:cocina_object) do
    build(:dro, id: 'druid:bc123df4567').new(description:)
  end
  let(:desc_md_xml) { Publish::PublicDescMetadataService.new(cocina_object, []).ng_xml(include_access_conditions: false) }

  describe '#ng_xml' do
    subject(:xml) { service.ng_xml }

    let(:description) do
      {
        title: [{ value: 'Slides, IA, Geodesic Domes [1 of 2]' }],
        purl: 'https://purl.stanford.edu/bc123df4567',
        form: [
          { value: 'still image', type: 'resource type', source: { value: 'MODS resource types' } },
          { value: 'photographs, color transparencies', type: 'form' }
        ],
        identifier: [
          { displayLabel: 'Image ID', type: 'local', value: 'M1090_S15_B01_F01_0055' }
        ],
        relatedResource: [
          { title: [{ value: 'Buckminster Fuller papers, 1920-1983' }],
            form: [{ value: 'collection', source: { value: 'MODS resource types' } }], type: 'part of' },
          { access: { physicalLocation: [{ value: 'Series 15 | Box 1 | Folder 1', type: 'location' }] }, type: 'part of' }
        ],
        access: { accessContact: [{ value: 'Stanford University. Libraries. Dept. of Special Collections and Stanford University Archives.', type: 'repository' }],
                  note: [{ value: 'Property rights reside with the repository. ' \
                                  'Intellectual rights to the images reside with the creators of the images or their heirs. ' \
                                  'To obtain permission to publish or reproduce, please contact the Public Services Librarian of the Dept. of Special Collections.' }] }
      }
    end

    let(:expected_xml) do
      <<~XML
        <?xml version="1.0"?>
        <oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:srw_dc="info:srw/schema/1/dc-schema" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
          <dc:title>Slides, IA, Geodesic Domes [1 of 2]</dc:title>
          <dc:relation type="collection">Buckminster Fuller papers, 1920-1983</dc:relation>
          <dc:type>StillImage</dc:type>
          <dc:format>photographs, color transparencies</dc:format>
          <dc:relation type="location">Series 15 | Box 1 | Folder 1</dc:relation>
          <dc:relation type="repository">Stanford University. Libraries. Dept. of Special Collections and Stanford University Archives.</dc:relation>
          <dc:identifier>M1090_S15_B01_F01_0055</dc:identifier>
          <dc:identifier>https://purl.stanford.edu/bc123df4567</dc:identifier>
          <dc:rights>Property rights reside with the repository. Intellectual rights to the images reside with the creators of the images or their heirs. To obtain permission to publish or reproduce, please contact the Public Services Librarian of the Dept. of Special Collections.</dc:rights>
        </oai_dc:dc>
      XML
    end

    it 'produces dublin core Stanford-specific mapping for repository, collection and location' do
      expect(xml).to be_equivalent_to expected_xml
    end
  end
end
