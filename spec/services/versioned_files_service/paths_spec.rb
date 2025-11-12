# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::Paths do
  let(:service) { described_class.new(druid:) }
  let(:druid) { 'druid:bc123df4567' }
  let(:s3_bucket) { Aws::S3::Bucket.new(Settings.s3.bucket, client: s3_client) }
  let(:s3_client) { S3ClientFactory.create_client }

  describe '#content_path' do
    let(:path) { service.content_path.to_s }

    it 'returns the expected path' do
      expect(path).to eq("content")
    end
  end

  describe '#versions_path' do
    let(:path) { service.versions_path.to_s }

    it 'returns the expected path' do
      expect(path).to eq("versions")
    end
  end

  describe '#cocina_path_for' do
    let(:path) { service.cocina_path_for(version: 2).to_s }

    it 'returns the expected path' do
      expect(path).to eq("versions/cocina.2.json")
    end
  end

  describe '#public_xml_path_for' do
    let(:path) { service.public_xml_path_for(version: 2).to_s }

    it 'returns the expected path' do
      expect(path).to eq("versions/public.2.xml")
    end
  end

  describe '#versions_manifest_path' do
    let(:path) { service.versions_manifest_path.to_s }

    it 'returns the expected path' do
      expect(path).to eq("versions/versions.json")
    end
  end

  describe '#content_path_for' do
    let(:path) { service.content_path_for(md5: '41446aec93ba8d401a33b46679a7dcaa').to_s }

    it 'returns the expected path' do
      expect(path).to eq("content/41446aec93ba8d401a33b46679a7dcaa")
    end
  end
end
