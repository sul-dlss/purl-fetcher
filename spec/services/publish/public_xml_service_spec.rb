# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Publish::PublicXmlService do
  subject(:service) do
    described_class.new(public_cocina:,
                        thumbnail_service:)
  end

  let(:thumbnail_service) { ThumbnailService.new(public_cocina) }

  let(:structural) do
    {
      contains: [{
        type: Cocina::Models::FileSetType.image,
        externalIdentifier: 'https://cocina.sul.stanford.edu/fileSet/9475bc2c-7552-43d8-b8ab-8cd2212d5873',
        label: 'Image 1',
        version: 1,
        structural: {
          contains: [{
            type: Cocina::Models::ObjectType.file,
            externalIdentifier: 'https://cocina.sul.stanford.edu/file/15e6e501-d22c-4f96-a824-8a88dd312937',
            label: 'Image 1',
            filename: 'wt183gy6220_00_0001.jp2',
            hasMimeType: 'image/jp2',
            size: 3_182_927,
            version: 1,
            access: {},
            administrative: {
              publish: false,
              sdrPreserve: false,
              shelve: false
            },
            hasMessageDigests: []
          }]
        }
      }],
      isMemberOf: []
    }
  end

  let(:druid) { 'druid:bc123df4567' }

  describe '#to_xml' do
    subject(:xml) { service.to_xml }

    let(:ng_xml) { Nokogiri::XML(xml) }

    before do
      mods = <<-EOXML
        <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   version="3.3"
                   xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd">
          <mods:identifier type="local" displayLabel="SUL Resource ID">druid:bc123df4567</mods:identifier>
        </mods:mods>
      EOXML

      allow(VirtualObject).to receive(:for).and_return([{ id: 'druid:hj097bm8879' }])
      allow_any_instance_of(Publish::PublicDescMetadataService).to receive(:ng_xml).and_return(Nokogiri::XML(mods)) # calls Item.find and not needed in general tests
    end

    context 'when there are no release tags' do
      let(:public_cocina) do
        build(:dro, id: druid)
      end

      it 'does not include a releaseData element and any info in identityMetadata' do
        expect(ng_xml.at_xpath('/publicObject/releaseData')).to be_nil
        expect(ng_xml.at_xpath('/publicObject/identityMetadata/release')).to be_nil
      end
    end

    context 'with an embargo' do
      let(:public_cocina) do
        build(:dro, id: druid).new(
          access: {
            view: 'world',
            download: 'world',
            embargo: {
              releaseDate: '2021-10-08T00:00:00Z'
            }
          }
        )
      end

      let(:result) do
        ng_xml.at_xpath('/publicObject/rightsMetadata/access[@type="read"]/machine/embargoReleaseDate').text
      end

      it 'adds embargo to the rights' do
        expect(result).to eq '2021-10-08T00:00:00Z'
      end
    end

    context 'with a problematic location code' do
      let(:public_cocina) do
        build(:dro, id: druid).new(
          access: {
            view: 'location-based',
            download: 'location-based',
            location: 'm&m'
          }
        )
      end

      let(:result) do
        ng_xml.at_xpath('/publicObject/rightsMetadata/access[@type="read"]/machine/location').text
      end

      it 'does not munge the location code' do
        expect(result).to eq 'm&m'
      end
    end

    context 'produces xml with' do
      let(:public_cocina) do
        build(:dro, id: druid, label: 'Constituent label &amp; A Special character').new(
          structural:,
          identification: {
            barcode: '36105132211504',
            catalogLinks: [
              { catalog: 'previous symphony', catalogRecordId: '9001001001', refresh: false },
              { catalog: 'symphony', catalogRecordId: '129483625', refresh: true },
              { catalog: 'previous folio', catalogRecordId: 'a9001001001', refresh: false },
              { catalog: 'folio', catalogRecordId: 'a129483625', refresh: true }
            ],
            sourceId: 'sul:123'
          }
        )
      end
      let(:now) { Time.now.utc }

      before do
        allow(Time).to receive(:now).and_return(now)
      end

      it 'an encoding of UTF-8' do
        expect(ng_xml.encoding).to match(/UTF-8/)
      end

      it 'an id attribute' do
        expect(ng_xml.at_xpath('/publicObject/@id').value).to match(/^druid:bc123df4567/)
      end

      it 'a published attribute' do
        expect(ng_xml.at_xpath('/publicObject/@published').value).to eq(now.xmlschema)
      end

      it 'a published version' do
        expect(ng_xml.at_xpath('/publicObject/@publishVersion').value).to eq("cocina-models/#{Cocina::Models::VERSION}")
      end

      it 'has identityMetadata with catkeys, barcode and sourceId' do
        expected = <<~XML
          <identityMetadata>
            <objectType>item</objectType>
            <objectLabel>Constituent label &amp; A Special character</objectLabel>
            <sourceId source="sul">sul:123</sourceId>
            <otherId name="catkey">129483625</otherId>
            <otherId name="folio_instance_hrid">a129483625</otherId>
            <otherId name="barcode">36105132211504</otherId>
          </identityMetadata>
        XML
        expect(ng_xml.at_xpath('/publicObject/identityMetadata').to_xml).to be_equivalent_to expected
      end

      context 'with no published files' do
        let(:structural) do
          {
            contains: []
          }
        end

        it 'has no contentMetadata element' do
          expect(ng_xml.at_xpath('/publicObject/contentMetadata')).not_to be
        end
      end

      describe 'with structural metadata that has a published file' do
        let(:structural) do
          {
            contains: [{
              type: Cocina::Models::FileSetType.image,
              externalIdentifier: 'https://cocina.sul.stanford.edu/fileSet/9475bc2c-7552-43d8-b8ab-8cd2212d5873',
              label: 'Image 1',
              version: 1,
              structural: {
                contains: [{
                  type: Cocina::Models::ObjectType.file,
                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/15e6e501-d22c-4f96-a824-8a88dd312937',
                  label: 'Image 1',
                  filename: 'wt183gy6220_00_0001.jp2',
                  hasMimeType: 'image/jp2',
                  size: 3_182_927,
                  version: 1,
                  access: {},
                  administrative: {
                    publish: true,
                    sdrPreserve: false,
                    shelve: false
                  },
                  hasMessageDigests: []
                }]
              }
            }]
          }
        end

        it 'rewrites the resource id so it can be used as a URI component' do
          expect(ng_xml.at_xpath('/publicObject/contentMetadata/resource[1]')['id']).to eq 'cocina-fileSet-bc123df4567-9475bc2c-7552-43d8-b8ab-8cd2212d5873'
        end
      end

      it 'generated mods' do
        expect(ng_xml.at_xpath('/publicObject/mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')).to be
      end

      it 'generated dublin core' do
        expect(ng_xml.at_xpath('/publicObject/oai_dc:dc', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/')).to be
      end

      context 'when a member of a collection' do
        let(:structural) do
          {
            contains: [{
              type: Cocina::Models::FileSetType.image,
              externalIdentifier: 'https://cocina.sul.stanford.edu/fileSet/9475bc2c-7552-43d8-b8ab-8cd2212d5873',
              label: 'Image 1',
              version: 1,
              structural: {
                contains: [{
                  type: Cocina::Models::ObjectType.file,
                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/15e6e501-d22c-4f96-a824-8a88dd312937',
                  label: 'Image 1',
                  filename: 'wt183gy6220_00_0001.jp2',
                  hasMimeType: 'image/jp2',
                  size: 3_182_927,
                  version: 1,
                  access: {},
                  administrative: {
                    publish: false,
                    sdrPreserve: false,
                    shelve: false
                  },
                  hasMessageDigests: []
                }]
              }
            }],
            isMemberOf: ['druid:xh235dd9059']
          }
        end

        before do
          allow(CocinaObjectStore).to receive(:find).and_return(build(:collection))
        end

        it 'exports relationships' do
          ns = {
            'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
            'fedora' => 'info:fedora/fedora-system:def/relations-external#'
          }
          expect(ng_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOfCollection', ns)).to be
          expect(ng_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isConstituentOf', ns)).to be
        end
      end

      context 'when no thumb is present' do
        let(:public_cocina) do
          build(:dro, id: druid)
        end

        it 'does not add a thumb node' do
          expect(ng_xml.at_xpath('/publicObject/thumb')).not_to be
        end
      end

      context 'when a thumb node is present' do
        it 'include a thumb node' do
          expect(ng_xml.at_xpath('/publicObject/thumb').to_xml).to be_equivalent_to('<thumb>bc123df4567/wt183gy6220_00_0001.jp2</thumb>')
        end
      end
    end

    context 'with a collection' do
      let(:public_cocina) do
        build(:collection, id: druid, label: 'Constituent label &amp; A Special character')
      end

      it 'publishes the expected datastreams' do
        expect(ng_xml.at_xpath('/publicObject/identityMetadata')).to be
        expect(ng_xml.at_xpath('/publicObject/rightsMetadata')).to be
        expect(ng_xml.at_xpath('/publicObject/mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')).to be
        expect(ng_xml.at_xpath('/publicObject/rdf:RDF', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')).to be
        expect(ng_xml.at_xpath('/publicObject/oai_dc:dc', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/')).to be
      end

      it 'has identityMetadata without a sourceId' do
        expected = <<~XML
          <identityMetadata>
            <objectType>collection</objectType>
            <objectLabel>Constituent label &amp; A Special character</objectLabel>
            <sourceId source="sul">sulcollection:1234</sourceId>
          </identityMetadata>
        XML
        expect(ng_xml.at_xpath('/publicObject/identityMetadata').to_xml).to be_equivalent_to expected
      end
    end

    context 'with external references' do
      let(:druid) { 'druid:hj097bm8879' }
      let(:public_cocina) do
        build(:dro, id: druid, type: Cocina::Models::ObjectType.map).new(structural:)
      end
      let(:structural) do
        {
          hasMemberOrders: [
            {
              members: ['druid:cg767mn6478', 'druid:jw923xn5254']
            }
          ]
        }
      end

      let(:cover_item) do
        Cocina::Models::DRO.new(
          { cocinaVersion: '0.65.1',
            type: Cocina::Models::ObjectType.image,
            externalIdentifier: 'druid:cg767mn6478',
            label: "Cover: Carey's American atlas.",
            version: 3,
            access: { view: 'world',
                      download: 'world',
                      copyright: 'Property rights reside with the repository, Copyright © Stanford University.',
                      useAndReproductionStatement: 'To obtain permission to publish or reproduce commercially, please contact the Digital & Rare Map Librarian',
                      license: 'https://creativecommons.org/licenses/by-nc-sa/3.0/legalcode' },
            administrative: {
              hasAdminPolicy: 'druid:sq161jk2248'
            },
            description: {
              title: [{
                value: "(Covers to) Carey's American Atlas: Containing Twenty Maps And One Chart ... Philadelphia: Engraved For, And Published By, Mathew Carey, " \
                       'No. 118, Market Street. M.DCC.XCV. [Price, Plain, Five Dollars-Coloured, Six Dollars.]'
              }, {
                value: "Cover: Carey's American atlas.",
                type: 'alternative',
                displayLabel: 'Short title'
              }],
              purl: 'https://purl.stanford.edu/cg767mn6478'
            },
            identification: { catalogLinks: [],
                              sourceId: 'Rumsey:2542A' },
            structural: {
              contains: [
                {
                  type: Cocina::Models::FileSetType.image,
                  externalIdentifier: 'https://cocina.sul.stanford.edu/fileSet/9475bc2c-7552-43d8-b8ab-8cd2212d5873',
                  label: 'Image 1',
                  version: 3,
                  structural: {
                    contains: [
                      { type: Cocina::Models::ObjectType.file,
                        externalIdentifier: 'https://cocina.sul.stanford.edu/file/15e6e501-d22c-4f96-a824-8a88dd312937',
                        label: '2542A.tif',
                        filename: '2542A.tif',
                        size: 92_217_124,
                        version: 3,
                        hasMimeType: 'image/tiff',
                        hasMessageDigests: [
                          { type: 'sha1',
                            digest: '1f09f8796bfa67db97557f3de48a96c87b286d32' },
                          { type: 'md5',
                            digest: '5b79c8570b7ef582735f912aa24ce5f2' }
                        ],
                        access: { view: 'world',
                                  download: 'world' },
                        administrative: { publish: false,
                                          sdrPreserve: true,
                                          shelve: false },
                        presentation: { height: 4747,
                                        width: 6475 } },
                      { type: Cocina::Models::ObjectType.file,
                        externalIdentifier: 'https://cocina.sul.stanford.edu/file/c59ada47-489b-4d0b-ab28-136b824d3904',
                        label: '2542A.jp2',
                        filename: '2542A.jp2',
                        size: 5_789_764,
                        version: 3,
                        hasMimeType: 'image/jp2',
                        hasMessageDigests: [{ type: 'sha1',
                                              digest: '39feed6ee1b734cab2d6a446e909a9fc7ac6fd01' }, { type: 'md5',
                                                                                                      digest: 'cd5ca5c4666cfd5ce0e9dc8c83461d7a' }],
                        access: { view: 'world',
                                  download: 'world' },
                        administrative: { publish: true,
                                          sdrPreserve: false,
                                          shelve: true },
                        presentation: { height: 4747,
                                        width: 6475 } }
                    ]
                  }
                }
              ]
            } }
        )
      end

      let(:title_item) do
        Cocina::Models::DRO.new(
          { cocinaVersion: '0.65.1',
            type: Cocina::Models::ObjectType.image,
            externalIdentifier: 'druid:jw923xn5254',
            label: "Title Page: Carey's American atlas.",
            version: 3,
            access: { view: 'world',
                      download: 'world',
                      copyright: 'Property rights reside with the repository, Copyright © Stanford University.',
                      useAndReproductionStatement: 'To obtain permission to publish or reproduce commercially, please contact the Digital & Rare Map Librarian',
                      license: 'https://creativecommons.org/licenses/by-nc-sa/3.0/legalcode' },
            administrative: { hasAdminPolicy: 'druid:sq161jk2248' },
            description: {
              title: [{
                value: "(Title Page to) Carey's American Atlas: Containing Twenty Maps And One Chart ... Philadelphia: Engraved For, And Published By, Mathew Carey, " \
                       'No. 118, Market Street. M.DCC.XCV. [Price, Plain, Five Dollars-Coloured, Six Dollars.]'
              }, {
                value: "Title Page: Carey's American atlas.",
                type: 'alternative',
                displayLabel: 'Short title'
              }],
              purl: 'https://purl.stanford.edu/jw923xn5254'
            },
            identification: {
              catalogLinks: [],
              sourceId: 'Rumsey:2542B'
            },
            structural: {
              contains: [
                {
                  type: Cocina::Models::FileSetType.image,
                  externalIdentifier: 'https://cocina.sul.stanford.edu/fileSet/929604b0-00bc-40b1-af71-5c17f066e2fd',
                  label: 'Image 1',
                  version: 3,
                  structural: {
                    contains: [
                      {
                        type: Cocina::Models::ObjectType.file,
                        externalIdentifier: 'https://cocina.sul.stanford.edu/file/787afaca-ba6e-4998-84bd-1bb43f9182cf',
                        label: '2542B.tif',
                        filename: '2542B.tif',
                        size: 44_028_890,
                        version: 3,
                        hasMimeType: 'image/tiff',
                        hasMessageDigests: [{ type: 'sha1',
                                              digest: 'a90aea983620238d8e1384d9a5cb683c6acd6984' }, { type: 'md5',
                                                                                                      digest: 'b5f6fcd6eb0ad02800aeb82cba6d0eed' }],
                        access: { view: 'world',
                                  download: 'world' },
                        administrative: { publish: false,
                                          sdrPreserve: true,
                                          shelve: false },
                        presentation: { height: 4675,
                                        width: 3139 }
                      },
                      {
                        type: Cocina::Models::ObjectType.file,
                        externalIdentifier: 'https://cocina.sul.stanford.edu/file/72880460-6865-4aa9-85c7-ac26002aebc5',
                        label: '2542B.jp2',
                        filename: '2542B.jp2',
                        size: 2_762_668,
                        version: 3,
                        hasMimeType: 'image/jp2',
                        hasMessageDigests: [
                          { type: 'sha1',
                            digest: '80454c111675ec7e2c425e909810c49a69ffef26' },
                          { type: 'md5',
                            digest: 'bccdbb2500bb139d6d622321bfd2aa57' }
                        ],
                        access: { view: 'world',
                                  download: 'world' },
                        administrative: { publish: true,
                                          sdrPreserve: false,
                                          shelve: true },
                        presentation: { height: 4675,
                                        width: 3139 }
                      }
                    ]
                  }
                }
              ]
            } }
        )
      end

      let(:expected_xml) do
        <<~XML
          <contentMetadata objectId="druid:hj097bm8879" type="map">
            <resource id="cocina-fileSet-hj097bm8879-9475bc2c-7552-43d8-b8ab-8cd2212d5873" sequence="1" type="image">
              <label>(Covers to) Carey's American Atlas: Containing Twenty Maps And One Chart ... Philadelphia: Engraved For, And Published By, Mathew Carey, No. 118, Market Street. M.DCC.XCV. [Price, Plain, Five Dollars-Coloured, Six Dollars.]</label>
              <externalFile fileId="2542A.jp2" objectId="druid:cg767mn6478" resourceId="cocina-fileSet-9475bc2c-7552-43d8-b8ab-8cd2212d5873" mimetype="image/jp2">
                <imageData width="6475" height="4747"/>
              </externalFile>
            </resource>
            <resource id="cocina-fileSet-hj097bm8879-929604b0-00bc-40b1-af71-5c17f066e2fd" sequence="2" type="image">
              <label>(Title Page to) Carey's American Atlas: Containing Twenty Maps And One Chart ... Philadelphia: Engraved For, And Published By, Mathew Carey, No. 118, Market Street. M.DCC.XCV. [Price, Plain, Five Dollars-Coloured, Six Dollars.]</label>
              <externalFile fileId="2542B.jp2" objectId="druid:jw923xn5254" resourceId="cocina-fileSet-929604b0-00bc-40b1-af71-5c17f066e2fd" mimetype="image/jp2">
                <imageData width="3139" height="4675"/>
              </externalFile>
            </resource>
          </contentMetadata>
        XML
      end

      it 'handles externalFile references' do
        allow(CocinaObjectStore).to receive(:find).with(cover_item.externalIdentifier).and_return(cover_item)
        allow(CocinaObjectStore).to receive(:find).with(title_item.externalIdentifier).and_return(title_item)
        expect(ng_xml.at_xpath('/publicObject/contentMetadata').to_xml).to be_equivalent_to(expected_xml)
      end
    end
  end
end
