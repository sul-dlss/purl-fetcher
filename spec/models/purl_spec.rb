require 'rails_helper'

RSpec.describe Purl do
  describe '#true_targets' do
    context 'when not deleted' do
      subject { create(:purl) }
      it 'has SearchWorksPreview' do
        expect(subject.true_targets).to include 'SearchWorksPreview'
      end
    end

    context 'when deleted' do
      subject { create(:purl) }
      it 'returns an empty array' do
        subject.update(deleted_at: Time.current)
        expect(subject.true_targets).to eq []
      end
    end
  end

  let(:druid) { 'druid:bb050dj7711' }

  describe '#refresh_collections' do
    subject { create(:purl) }
    it 'removes previous collections and adds new ones' do
      subject.collections << create_list(:collection, 3)
      expect { subject.refresh_collections(['druid:1', 'druid:2']) }
        .to change { subject.collections.count }.from(3).to(2)
    end
  end

  describe '.membership' do
    context 'when passed "none"' do
      before do
        create_list(:purl, 4)
        create(:purl, :with_collection)
      end

      it 'returns objects that do not belong to a collection' do
        objects = described_class.membership('membership' => 'none')
        expect(objects.count).to eq 4
        objects.each do |purl|
          expect(purl.collections).to be_empty
        end
      end
    end

    context 'when passed "collection"' do
      before do
        create(:purl)
        create_list(:purl, 4, :with_collection)
      end

      it 'returns objects that only belong to a collection' do
        objects = described_class.membership('membership' => 'collection')
        expect(objects.count).to eq 4
        objects.each do |purl|
          expect(purl.collections.count).to eq 1
        end
      end
    end

    context 'anything else' do
      it 'returns everything' do
        expect(described_class.membership('yolo').count).to eq described_class.count
      end
    end
  end

  describe '.status' do
    context 'when passed "deleted"' do
      before do
        create(:purl)
        3.times { create(:purl, deleted_at: Time.zone.now) }
      end

      it 'returns objects that have been deleted' do
        objects = described_class.status('deleted')
        expect(objects.count).to eq 3
      end
    end

    context 'when passed "public"' do
      before do
        create_list(:purl, 5)
        create(:purl, deleted_at: Time.zone.now)
      end

      it 'returns objects that are still public' do
        objects = described_class.status('public')
        expect(objects.count).to eq 5
      end
    end
  end

  describe '.target' do
    context 'when passed a valid target' do
      before do
        create_list(:purl, 2, :with_release_tags)
        create(:purl)
      end

      it 'returns objects that have that target' do
        objects = described_class.target('Searchworks')
        expect(objects.count).to eq 2
      end
    end

    context 'when passed an invalid target' do
      before do
        create(:purl, :with_release_tags)
      end

      it 'returns nothing' do
        objects = described_class.target('SuperCoolStuff')
        expect(objects.count).to eq 0
      end
    end
  end

  describe '#deleted_at?' do
    subject { purl.deleted_at? }
    let(:purl) { described_class.create(druid:) }

    it { is_expected.to be false }
  end

  describe '#mark_deleted' do
    subject(:mark_deleted) { purl.mark_deleted }
    let!(:purl) { create(:purl, :with_release_tags, :with_collection, druid:) }

    it 'marks a record as deleted' do
      mark_deleted
      expect(purl.deleted_at?).to be true
    end

    it 'cleans up release_tags' do
      expect { mark_deleted }.to change { purl.release_tags.count }.from(2).to(0)
    end

    it 'cleans up collections' do
      expect { mark_deleted }.to change { purl.collections.count }.from(1).to(0)
    end
  end

  describe '#refresh_release_tags' do
    subject(:purl) { build(:purl) }

    it 'does not duplicate tags for existing release targets' do
      purl.refresh_release_tags('index' => ['Searchworks'], 'delete' => [])
      expect(purl.release_tags).to contain_exactly(an_object_having_attributes(name: 'Searchworks', release_type: true))

      purl.refresh_release_tags('index' => ['Searchworks'], 'delete' => [])
      expect(purl.release_tags).to contain_exactly(an_object_having_attributes(name: 'Searchworks', release_type: true))

      purl.refresh_release_tags('index' => [], 'delete' => ['Searchworks'])
      expect(purl.release_tags).to contain_exactly(an_object_having_attributes(name: 'Searchworks', release_type: false))
    end
  end
end
