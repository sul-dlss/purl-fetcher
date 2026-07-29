# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::UpdateAction do
  let(:action) { described_class.new(version: 1, version_metadata:, cocina:, file_transfers: {}, object:) }

  let(:druid) { 'druid:bc123df4567' }
  let(:object) { VersionedFilesService::Object.new(druid) }
  let(:version_metadata) { VersionedFilesService::VersionsManifest::VersionMetadata.new(version: 1, state: 'available', date: DateTime.now) }

  let(:stacks_pathname) { 'tmp/stacks' }
  let(:versions_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions" }

  let(:cocina) do
    build(:dro_with_metadata, id: druid).new(
      description: { title: [{ value: "Main title" }], purl: 'https://purl.stanford.edu/bc123df4567' },
      access: { view: 'world', download: 'world' }
    )
  end

  before do
    allow(Settings.filesystems).to receive(:stacks_root).and_return(stacks_pathname)
  end

  after do
    FileUtils.rm_rf(stacks_pathname)
  end

  describe '#call' do
    it 'writes the label from the public cocina into cocina.json' do
      action.call

      written = JSON.parse(File.read("#{versions_path}/cocina.1.json"))
      expect(written['label']).to eq 'Main title'
    end

    context "when the cocina object no longer has a label" do
      let(:cocina) { build(:dro_with_metadata, id: druid).new(access: { view: 'world', download: 'world' }) }

      it 'uses the title-derived label' do
        action.call

        written = JSON.parse(File.read("#{versions_path}/cocina.1.json"))
        expect(written['label']).to eq 'factory DRO title'
      end
    end
  end
end
