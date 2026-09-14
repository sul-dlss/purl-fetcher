# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::VersionsManifest do
  subject(:manifest) { described_class.new(path: pathname) }

  let(:pathname) { Pathname.new('tmp/versions_manifest.json') }

  after do
    pathname.delete if pathname.exist?
  end

  describe '.update_version' do
    context 'when backfilling withdrawn versions' do
      let(:now) { DateTime.now }

      let(:expected_manifest) do
        {
          "$schemaVersion" => 1,
          'head' => 3,
          'versions' => {
            '1' => { 'state' => 'permanently_withdrawn' },
            '2' => { 'state' => 'permanently_withdrawn' },
            '3' => { 'state' => 'available', 'date' => now.iso8601 }
          }
        }
      end

      it 'backfills withdrawn versions' do
        manifest.update_version(version: 3, version_metadata: described_class::VersionMetadata.new(version: 3, state: 'available', date: now))

        expect(JSON.parse(pathname.read)).to eq expected_manifest
      end
    end
  end
end
