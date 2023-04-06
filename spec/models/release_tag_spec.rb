require 'rails_helper'

describe ReleaseTag do
  let(:purl) { Purl.find(1) }

  context 'reads data correctly' do
    it '.release_tags' do
      tags = purl.release_tags.to_h { |tag| [ tag.name, tag.release_type ] }
      expect(tags).to include('Revs' => true, 'SearchWorks' => true)
    end
  end

  context 'updates duplicate tags correctly' do
    it 'finds prior tags using unique composite key' do
      tag = described_class.find_by(purl_id: purl.id, name: 'Revs')
      expect(tag).to be_an described_class
    end

    it 'enforces uniqueness for composite key' do
      tag = described_class.create(purl_id: purl.id, name: 'SomethingWonderful', release_type: false)
      tag = described_class.create(purl_id: purl.id, name: 'SomethingWonderful', release_type: true) # again
      expect { tag.save! }.to raise_error(ActiveRecord::RecordInvalid, /Name has already been taken/)
    end

    describe '.for' do
      it 'will overwrite prior tags' do
        tag = described_class.for(purl, 'Revs', false)
        expect(tag.release_type).to be_falsey     # sets type
        expect(tag.new_record?).to be_falsey      # reuses
        expect(tag.changed?).to be_truthy         # not saved
        expect { tag.save! }.not_to raise_error   # saves ok
      end

      it 'will create new tags' do
        expect(described_class.find_by(purl_id: purl.id, name: 'SomethingWonderful')).to be_nil
        expect(described_class.for(purl, 'SomethingWonderful', false)).to be_an described_class
      end
    end
  end
end
