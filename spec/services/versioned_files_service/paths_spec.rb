# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::Paths do
  let(:service) { described_class.new(druid:) }
  let(:druid) { 'druid:bc123df4567' }

  let(:stacks_pathname) { 'tmp/stacks' }

  before do
    allow(Settings.filesystems).to receive_messages(stacks_root: stacks_pathname)
  end

  describe '#object_path' do
    let(:path) { service.object_path.to_s }

    it 'returns the expected path' do
      expect(path).to eq("#{stacks_pathname}/bc/123/df/4567/bc123df4567")
    end
  end

  describe '#content_path' do
    let(:path) { service.content_path.to_s }

    it 'returns the expected path' do
      expect(path).to eq("#{stacks_pathname}/bc/123/df/4567/bc123df4567/content")
    end
  end

  describe '#versions_path' do
    let(:path) { service.versions_path.to_s }

    it 'returns the expected path' do
      expect(path).to eq("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions")
    end
  end

  describe '#head_cocina_path' do
    let(:version_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions" }
    let(:path) { service.head_cocina_path.to_s }

    before do
      # create version manifest to find head version
      FileUtils.mkdir_p(version_path)
      manifest = { head: 3 }
      File.write("#{version_path}/versions.json", manifest.to_json)
    end

    after do
      FileUtils.rm_rf(version_path)
    end

    it 'returns the expected path' do
      expect(path).to eq("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions/cocina.3.json")
    end
  end

  describe '#cocina_path_for' do
    let(:path) { service.cocina_path_for(version: 2).to_s }

    it 'returns the expected path' do
      expect(path).to eq("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions/cocina.2.json")
    end
  end

  describe '#public_xml_path_for' do
    let(:path) { service.public_xml_path_for(version: 2).to_s }

    it 'returns the expected path' do
      expect(path).to eq("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions/public.2.xml")
    end
  end

  describe '#versions_manifest_path' do
    let(:path) { service.versions_manifest_path.to_s }

    it 'returns the expected path' do
      expect(path).to eq("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions/versions.json")
    end
  end

  describe '#content_path_for' do
    let(:path) { service.content_path_for(md5: '41446aec93ba8d401a33b46679a7dcaa').to_s }

    it 'returns the expected path' do
      expect(path).to eq("#{stacks_pathname}/bc/123/df/4567/bc123df4567/content/41446aec93ba8d401a33b46679a7dcaa")
    end
  end
end
