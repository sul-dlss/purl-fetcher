# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FilesByMd5Service do
  let(:files_by_md5) { described_class.call(purl: purl_object) }

  let!(:purl_object) { create(:purl, druid:) }
  let(:druid) { 'druid:bc123df4567' }
  let(:s3_bucket) { Aws::S3::Bucket.new(Settings.s3.bucket, client: s3_client) }
  let(:s3_client) { S3ClientFactory.create_client }

  before do
    allow(Honeybadger).to receive(:notify)
  end

  context 'when object is versioned' do
    let(:content_path) { "bc/123/df/4567/bc123df4567/content" }
    let(:versions_path) { "bc/123/df/4567/bc123df4567/versions" }

    let(:dro) do
      build(:dro_with_metadata, id: druid).new(access: { view: 'world', download: 'world' },
                                               structural:
    Cocina::Models::DROStructural.new(
      contains: [
        Cocina::Models::FileSet.new(
          externalIdentifier: 'bc123df4567_2',
          type: Cocina::Models::FileSetType.file,
          label: 'text file',
          version: 1,
          structural: Cocina::Models::FileSetStructural.new(
            contains: [
              Cocina::Models::File.new(
                externalIdentifier: '1234',
                type: Cocina::Models::ObjectType.file,
                label: 'the regular file',
                filename: 'file2.txt',
                size: 9, # write_version uses the file name for the file content
                version: 1,
                hasMessageDigests: [
                  { type: 'md5', digest: '3e25960a79dbc69b674cd4ec67a72c62' }
                ],
                administrative: {
                  publish: true,
                  shelve: true
                }
              ),
              Cocina::Models::File.new(
                externalIdentifier: '1234',
                type: Cocina::Models::ObjectType.file,
                label: 'the hierarchical file',
                filename: 'files/file2.txt',
                size: 15, # write_version uses the file name for the file content
                version: 1,
                hasMessageDigests: [
                  { type: 'md5', digest: '5997de4d5abb55f21f652aa61b8f3aaf' }
                ],
                administrative: {
                  publish: true,
                  shelve: true
                }
              )
            ]
          )
        )
      ]
    ))
    end

    before do
      write_version(content_path:, versions_path:, cocina_object: dro)
      VersionedFilesService::Object.new(druid).delete_content(md5: '5997de4d5abb55f21f652aa61b8f3aaf')
    end

    after do
      s3_bucket.clear!
    end

    it 'returns the files by md5' do
      expect(files_by_md5).to eq([
                                   { "3e25960a79dbc69b674cd4ec67a72c62" => "file2.txt" }
                                 ])
      expect(Honeybadger).to have_received(:notify).with("File missing from shelves", context: { path: "content/5997de4d5abb55f21f652aa61b8f3aaf", druid:, expected_size: 15 })
    end
  end
end
