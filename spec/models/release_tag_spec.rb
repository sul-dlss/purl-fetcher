require 'rails_helper'

RSpec.describe ReleaseTag do
  let(:purl) { create(:purl, :with_release_tags) }

  describe '#release_tags' do
    it 'reads the data' do
      tags = purl.release_tags.to_h { |tag| [ tag.name, tag.release_type ] }
      expect(tags).to include('PURL sitemap' => true, 'Searchworks' => true)
    end
  end

  describe 'updating duplicate tags' do
    it 'finds prior tags using unique composite key' do
      tag = described_class.find_by(purl_id: purl.id, name: 'PURL sitemap')
      expect(tag).to be_an described_class
    end

    it 'enforces uniqueness for composite key' do
      tag = described_class.create(purl_id: purl.id, name: 'SomethingWonderful', release_type: false)
      tag = described_class.create(purl_id: purl.id, name: 'SomethingWonderful', release_type: true) # again
      expect { tag.save! }.to raise_error(ActiveRecord::RecordInvalid, /Name has already been taken/)
    end

    describe '.for' do
      it 'overwrites prior tags' do
        tag = described_class.for(purl, 'PURL sitemap', false)
        expect(tag.release_type).to be_falsey     # sets type
        expect(tag.new_record?).to be_falsey      # reuses
        expect(tag.changed?).to be_truthy         # not saved
        expect { tag.save! }.not_to raise_error   # saves ok
      end

      it 'creates new tags' do
        expect(described_class.find_by(purl_id: purl.id, name: 'SomethingWonderful')).to be_nil
        expect(described_class.for(purl, 'SomethingWonderful', false)).to be_an described_class
      end
    end
  end
end
