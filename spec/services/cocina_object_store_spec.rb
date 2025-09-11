require 'rails_helper'

RSpec.describe CocinaObjectStore do
  let(:druid) { 'druid:bc123df4567' }
  let!(:object) { create(:purl, druid: druid) }
  let(:stacks_pathname) { 'tmp/stacks' }
  let(:cocina_json) { create(:public_json, purl: object).data }

  before do
    allow(Settings.filesystems).to receive_messages(
      stacks_root: stacks_pathname
    )
    FileUtils.rm_rf(stacks_pathname)
  end

  after do
    FileUtils.rm_rf(stacks_pathname)
  end

  describe '.find' do
    context 'when the cocina.json exists in the versioned stacks path' do
      before do
        # Create the file
        stacks_versions_path = Pathname.new("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions")
        FileUtils.mkdir_p(stacks_versions_path.to_s)
        File.write("#{stacks_versions_path}/cocina.json", cocina_json)
      end

      it 'returns a Cocina::Models::DROWithMetadata object' do
        result = described_class.find(druid)
        expect(result).to be_a(Cocina::Models::DROWithMetadata)
      end
    end
  end
end
