require 'rails_helper'

describe PurlParser do
  describe('bb050dj7711') do
    let(:sample_doc_path) { DruidTools::PurlDruid.new('bb050dj7711', purl_fixture_path).path }
    let(:purl) { described_class.new(sample_doc_path) }

    it 'gets the title from the mods file' do
      expect(purl.title).to eq("This is Pete's New Test title for this object.")
    end

    it 'gets the druid from publicMetadata' do
      expect(purl.canonical_druid).to match('druid:bb050dj7711')
    end

    it 'gets true and false data from the public xml regarding release status' do
      expect(purl.releases).to match(false: ['Atago'], true: ['CARRICKR-TEST', 'Robot_Testing_Feb_5_2015'])
    end

    it 'gets the object type' do
      expect(purl.object_type).to match('item')
    end

    it 'gets the collections the object is a member of' do
      expect(purl.collections).to match(['druid:nt028fd5773', 'druid:wn860zc7322'])
    end

    it 'returns empty string when no cat key is present' do
      expect(purl.catkey).to match('')
    end
  end

  describe('ct961sj2730') do
    let(:sample_doc_path) { DruidTools::PurlDruid.new('ct961sj2730', purl_fixture_path).path }
    let(:purl) { described_class.new(sample_doc_path) }

    it 'gets the cat key when one is present' do
      expect(purl.catkey).to match('10357851')
    end

    it 'gets multiple object types when an object has multiple types' do
      expect(purl.object_type).to match('collection|set')
    end
  end

  describe('bb050dj0000') do
    let(:sample_doc_path) { DruidTools::PurlDruid.new('bb050dj0000', purl_fixture_path).path }
    let(:purl) { described_class.new(sample_doc_path) }

    it 'does not find the public xml' do
      expect(purl.exists?).to be_falsey
    end
  end

  describe '#published_at' do
    let(:sample_doc_path) do
      DruidTools::PurlDruid.new('bb050dj7711', purl_fixture_path).path
    end

    subject { described_class.new(sample_doc_path) }
    it 'gets the published_at metadata directly from the public XML' do
      expect(subject.published_at).to be_an Time
      expect(subject.published_at.zone).to eq('UTC') # this is the local timezone for our Rails instances
      # the metadata is actually in a non-UTC zone so we ensure it gets converted to the local timezone (UTC)
      expect(subject.published_at.iso8601).to eq('2015-04-09T20:20:16Z')
    end
  end

  describe('nc687px4289') do
    let(:sample_doc_path) { DruidTools::PurlDruid.new('nc687px4289', purl_fixture_path).path }
    let(:purl) { described_class.new(sample_doc_path) }

    it 'uses the first title' do
      expect(purl.public_xml.xpath('//*[name()="dc:title"]').size).to eq 2 # multiple titles
      expect(purl.title).to eq('Kitaĭ')
    end
  end
end
