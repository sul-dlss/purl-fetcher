require 'rails_helper'

RSpec.describe PurlXmlUpdater, type: :model do
  let(:purl_object) { create(:purl) }
  let(:druid) { 'druid:bb050dj7711' }
  let(:instance) { described_class.new(purl_object) }

  describe '#update' do
    subject { instance.update }

    context 'when valid' do
      before do
        purl_object.update(druid: 'druid:bb050dj7711')
        instance.update
      end

      it 'updates an instance from public xml' do
        purl_object.update(druid: 'druid:bb050dj7711')
        instance.update
        expect(purl_object.druid).to eq 'druid:bb050dj7711'
        expect(purl_object.title).to eq 'This is Pete\'s New Test title for this object.'
        expect(purl_object.release_tags.count).to eq 3
        expect(purl_object.collections.count).to eq 2
        expect(purl_object.published_at.iso8601).to eq '2015-04-09T20:20:16Z' # should be in UTC
        expect(purl_object.deleted_at).to be_nil
        expect(purl_object.public_xml&.data).to be_present.and include '<publicObject id="druid:bb050dj7711"'
      end
    end

    context 'when public xml is unavailable' do
      it { is_expected.to be false }
    end

    context 'when validations fail' do
      before do
        create(:purl, druid: 'druid:bb050dj7711')
        purl_object.update(druid: 'druid:bb050dj7711')
      end

      it 'raises an exception' do
        expect { instance.update }.to raise_exception(ActiveRecord::RecordInvalid)
      end
    end
  end
end
