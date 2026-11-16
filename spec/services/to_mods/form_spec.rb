# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ToMods::Form do
  subject(:xml) { writer.to_xml }

  let(:writer) do
    Nokogiri::XML::Builder.new do |xml|
      xml.mods('xmlns' => 'http://www.loc.gov/mods/v3',
               'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
               'version' => '3.6',
               'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd') do
        described_class.write(xml: xml, forms: forms.as_json, id_generator: nil)
      end
    end
  end

  context 'when form is nil' do
    let(:forms) { nil }

    it 'builds the xml' do
      expect(xml).to be_equivalent_to <<~XML
        <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns="http://www.loc.gov/mods/v3" version="3.6"
          xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd">
        </mods>
      XML
    end
  end

  context 'with typical self-deposit forms (i.e., with datacite metadata)' do
    let(:forms) do
      [
        { structuredValue: [
            { value: 'Image',
              type: 'type' }
          ],
          type: 'resource type',
          source: { value: 'Stanford self-deposit resource types' } },
        { value: 'still image',
          type: 'resource type',
          source: { value: 'MODS resource types' } },
        { value: 'Image',
          type: 'resource type',
          source: { value: 'DataCite resource types' } }
      ]
    end

    it 'builds the xml' do
      expect(xml).to be_equivalent_to <<~XML
        <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns="http://www.loc.gov/mods/v3" version="3.6"
          xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd">
         <genre type="H2 type">Image</genre>
         <typeOfResource>still image</typeOfResource>
         <extension displayLabel="datacite">
           <resourceType resourceTypeGeneral="Image">Image</resourceType>
         </extension>
        </mods>
      XML
    end
  end

  context 'with typical ETD forms (i.e., with datacite metadata)' do
    let(:forms) do
      [
        { value: 'text',
          type: 'resource type',
          source: { value: 'MODS resource types' } },
        { value: 'theses',
          type: 'genre',
          source: { code: 'marcgt' } },
        { value: 'electronic resource',
          type: 'form',
          source: { code: 'marccategory' } },
        { value: 'computer',
          type: 'media',
          source: { code: 'rdamedia' } },
        { value: 'online resource',
          type: 'carrier',
          source: { code: 'rdacarrier' } },
        { value: '1 online resource',
          type: 'extent' },
        { structuredValue: [
            { value: 'Academic thesis',
              type: 'type' }
          ],
          type: 'resource type',
          source: { value: 'Stanford self-deposit resource types' } },
        { value: 'Dissertation',
          type: 'resource type',
          source: { value: 'DataCite resource types' } }
      ]
    end

    it 'builds the xml' do
      expect(xml).to be_equivalent_to <<~XML
        <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns="http://www.loc.gov/mods/v3" version="3.6"
          xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd">
          <genre type="H2 type">Academic thesis</genre>
          <extension displayLabel="datacite">
            <resourceType resourceTypeGeneral="Dissertation">Academic thesis</resourceType>
          </extension>
          <typeOfResource>text</typeOfResource>
          <genre authority="marcgt">theses</genre>
          <physicalDescription>
            <form authority="marccategory">electronic resource</form>
            <form type="media" authority="rdamedia">computer</form>
            <form type="carrier" authority="rdacarrier">online resource</form>
            <extent>1 online resource</extent>
          </physicalDescription>
        </mods>
      XML
    end
  end
end
