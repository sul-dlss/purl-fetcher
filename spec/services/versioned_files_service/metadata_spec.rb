# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::Metadata do
  describe '.deep_compact_blank' do
    subject { described_class.deep_compact_blank(input) }

    context 'with false values' do
      let(:input) do
        {
          administrative: {
            publish: true,
            sdrPreserve: false,
            shelve: true
          }
        }
      end

      it { is_expected.to eq(input) }
    end
  end

  describe '#write_cocina' do
    let(:druid) { 'druid:bc123df4567' }
    let(:stacks_pathname) { 'tmp/stacks' }
    let(:versions_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions" }
    let(:paths) { VersionedFilesService::Paths.new(druid:) }
    let(:metadata) { described_class.new(paths:) }
    let(:cocina) { build(:dro_with_metadata, id: druid).new(access: { view: 'world', download: 'world' }) }

    before do
      allow(Settings.filesystems).to receive(:stacks_root).and_return(stacks_pathname)
    end

    after do
      FileUtils.rm_rf(stacks_pathname)
    end

    it 'merges the given label into the written cocina json' do
      metadata.write_cocina(version: 1, cocina:, label: 'Computed label')

      written = JSON.parse(File.read("#{versions_path}/cocina.1.json"))
      expect(written['label']).to eq 'Computed label'
    end

    it "overrides the cocina object's own label" do
      cocina_with_label = cocina.new(label: 'Original label')

      metadata.write_cocina(version: 1, cocina: cocina_with_label, label: 'Computed label')

      written = JSON.parse(File.read("#{versions_path}/cocina.1.json"))
      expect(written['label']).to eq 'Computed label'
    end
  end
end
