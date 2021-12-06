require 'rails_helper'

describe Purl, type: :model do
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

  describe '#update_from_public_xml!' do
    let(:purl_object) { create(:purl) }

    it 'updates an instance from public xml' do
      purl_object.update(druid: 'druid:bb050dj7711')
      purl_object.update_from_public_xml!
      expect(purl_object.druid).to eq 'druid:bb050dj7711'
      expect(purl_object.title).to eq 'This is Pete\'s New Test title for this object.'
      expect(purl_object.release_tags.count).to eq 3
      expect(purl_object.collections.count).to eq 2
      expect(purl_object.published_at.iso8601).to eq '2015-04-09T20:20:16Z' # should be in UTC
      expect(purl_object.deleted_at).to be_nil
    end

    context 'public xml unavailable' do
      it { expect(purl_object.update_from_public_xml!).to be false }
    end

    context 'validations' do
      it 'raises exceptions if the validations fail' do
        create(:purl, druid: 'druid:bb050dj7711')
        purl_object.update(druid: 'druid:bb050dj7711')
        expect { purl_object.update_from_public_xml! }.to raise_exception(ActiveRecord::RecordInvalid)
      end
    end

    context 'public xml association' do
      before do
        purl_object.update(druid: 'druid:bb050dj7711')
        purl_object.update_from_public_xml!
      end

      it 'stores the public xml in the database' do
        expect(purl_object.public_xml&.data).to be_present.and include '<publicObject id="druid:bb050dj7711"'
      end
    end
  end

  describe '.membership' do
    context 'when passed "none"' do
      it 'returns objects that do not belong to a collection' do
        objects = described_class.membership('membership' => 'none')
        expect(objects.count).to eq 4
        objects.each do |purl|
          expect(purl.collections).to be_empty
        end
      end
    end

    context 'when passed "collection"' do
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
        expect(described_class.membership('yolo').count).to eq described_class.all.count
      end
    end
  end

  describe '.status' do
    context 'when passed "deleted"' do
      it 'returns objects that have been deleted' do
        objects = described_class.status('status' => 'deleted')
        expect(objects.count).to eq 3
      end
    end

    context 'when passed "collection"' do
      it 'returns objects that are still public' do
        objects = described_class.status('status' => 'public')
        expect(objects.count).to eq 5
      end
    end

    context 'anything else' do
      it 'returns everything' do
        expect(described_class.status('yolo').count).to eq described_class.all.count
      end
    end
  end

  describe '.target' do
    context 'when passed a valid target' do
      it 'returns objects that have that target' do
        objects = described_class.target('target' => 'SearchWorks')
        expect(objects.count).to eq 2
      end
    end

    context 'when passed an invalid target' do
      it 'returns nothing' do
        objects = described_class.target('target' => 'SuperCoolStuff')
        expect(objects.count).to eq 0
      end
    end

    context 'anything else' do
      it 'returns everything' do
        expect(described_class.target('yolo').count).to eq described_class.all.count
      end
    end
  end

  describe '.mark_deleted' do
    it 'always starts without deleted_at time' do
      purl = described_class.create(druid: druid)
      expect(purl.deleted_at?).to be_falsey
    end

    it 'marks a record as deleted' do
      expect(described_class.mark_deleted(druid)).to be_truthy
      purl = described_class.find_by_druid(druid)
      expect(purl.deleted_at?).to be_truthy
    end

    it 'marks a record as deleted with a given timestamp' do
      deleted_at_time = Time.current
      expect(described_class.mark_deleted(druid, deleted_at_time)).to be_truthy
      purl = described_class.find_by(druid: druid)
      expect(purl.deleted_at.iso8601).to eq deleted_at_time.iso8601 # favorable compare which removes milliseconds
    end

    it 'cleans up release_tags' do
      purl = described_class.find(1)
      expect{ described_class.mark_deleted(purl.druid) }
        .to change { purl.release_tags.count }.from(2).to(0)
    end

    it 'cleans up collections' do
      purl = described_class.find(1)
      expect{ described_class.mark_deleted(purl.druid) }
        .to change { purl.collections.count }.from(1).to(0)
    end
  end
end
