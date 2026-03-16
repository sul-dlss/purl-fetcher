# frozen_string_literal: true

MODS_ATTRIBUTES = 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" version="3.7"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-7.xsd"'

def add_purl_and_title(cocina, druid)
  cocina.merge({
    purl: cocina.fetch(:purl, Cocina::Models::Mapping::Purl.for(druid: druid)),
    title: cocina.key?(:title) ? nil : [{ value: label }]
  }.compact)
end

RSpec.shared_examples 'cocina to MODS' do |expected_xml|
  subject(:xml) { writer.to_xml }

  # writer object is declared in the context of calling examples

  let(:mods_attributes) do
    {
      'xmlns' => 'http://www.loc.gov/mods/v3',
      'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
      'version' => '3.6',
      'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd'
    }
  end

  it 'builds the expected xml' do
    expect(xml).to be_equivalent_to <<~XML
      <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns="http://www.loc.gov/mods/v3" version="3.6"
        xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd">
        #{expected_xml}
      </mods>
    XML
  end
end

# When starting from MODS.
RSpec.shared_examples 'MODS cocina mapping' do
  # Required: mods, cocina
  # Optional: druid, roundtrip_mods, warnings, errors, mods_attributes, skip_normalization, label

  let(:orig_cocina_description) { Cocina::Models::Description.new(add_purl_and_title(cocina, local_druid)) }

  let(:orig_mods_ng) { ng_mods_for(mods, mods_attributes) }

  let(:mods_attributes) { MODS_ATTRIBUTES }

  let(:roundtrip_mods_ng) { defined?(roundtrip_mods) ? ng_mods_for(roundtrip_mods, MODS_ATTRIBUTES) : nil }

  let(:local_druid) { defined?(druid) ? druid : 'druid:zn746hz1696' }

  let(:skip_normalization) { false }

  let(:label) { 'Test title' }

  context 'when mapping to MODS (from cocina)' do
    let(:expected_mods_ng) do
      ModsNormalizer.normalize_purl_and_missing_title(mods_ng_xml: roundtrip_mods_ng || orig_mods_ng, druid: local_druid,
                                                      label: label)
    end

    let(:actual_mods_ng) { ToMods::Description.transform(orig_cocina_description, local_druid) }

    let(:actual_xml) { actual_mods_ng.to_xml }

    it 'cocina Description maps to expected MODS' do
      expect(actual_xml).to be_equivalent_to expected_mods_ng.to_xml
    end
  end
end

# When starting from cocina, e.g., H2 and roundtrips.
RSpec.shared_examples 'cocina MODS mapping' do
  # Required: mods, cocina
  # Optional: druid, roundtrip_cocina, warnings, errors, mods_attributes, label

  let(:orig_cocina_description) { Cocina::Models::Description.new(add_purl_and_title(cocina, local_druid)) }

  let(:mods_attributes) { MODS_ATTRIBUTES }

  let(:mods_ng) { ng_mods_for(mods, mods_attributes) }

  let(:mods_xml) { mods_ng.to_xml }

  let(:local_druid) { defined?(druid) ? druid : 'druid:zn746hz1696' }

  let(:label) { 'Test title' }

  context 'when mapping from cocina (to MODS)' do
    let(:actual_mods_ng) { ToMods::Description.transform(orig_cocina_description, local_druid) }

    let(:actual_xml) { actual_mods_ng.to_xml }

    it 'mods snippet(s) produce valid MODS' do
      expect { mods_ng }.not_to raise_error
    end

    # as we are starting with a cocina representation, there may be empty cocina values
    # which could result in empty MODS elements from the transform.  The empty elements are correct at this point.
    it 'cocina Description maps to expected MODS' do
      expect(actual_xml).to be_equivalent_to ModsNormalizer.normalize_purl_and_missing_title(mods_ng_xml: mods_ng, druid: local_druid,
                                                                                             label: label).to_xml
    end
  end
end

# When starting from cocina, e.g., H2 and does not (intentionally) roundtrip.
RSpec.shared_examples 'cocina to MODS only mapping' do
  # Required: mods, cocina
  # Optional: druid, label

  let(:orig_cocina_description) { Cocina::Models::Description.new(add_purl_and_title(cocina, local_druid)) }

  let(:mods_attributes) { MODS_ATTRIBUTES }

  let(:mods_ng) { ng_mods_for(mods, mods_attributes) }

  let(:local_druid) { defined?(druid) ? druid : 'druid:zn746hz1696' }

  let(:label) { 'Test title' }

  context 'when mapping from cocina (to MODS)' do
    let(:actual_mods_ng) { ToMods::Description.transform(orig_cocina_description, local_druid) }

    let(:actual_xml) { actual_mods_ng.to_xml }

    it 'mods snippet(s) produce valid MODS' do
      expect { mods_ng }.not_to raise_error
    end

    # as we are starting with a cocina representation, there may be empty cocina values
    # which could result in empty MODS elements from the transform.  The empty elements are correct at this point.
    it 'cocina Description maps to expected MODS' do
      expect(actual_xml).to be_equivalent_to ModsNormalizer.normalize_purl_and_missing_title(mods_ng_xml: mods_ng, druid: local_druid,
                                                                                             label: label).to_xml
    end
  end
end

def ng_mods_for(snippet, mods_attributes)
  xml = <<~XML
    <mods #{mods_attributes}>
      #{snippet}
    </mods>
  XML
  Nokogiri.XML(xml, nil, 'UTF-8', Nokogiri::XML::ParseOptions.new.strict)
end
