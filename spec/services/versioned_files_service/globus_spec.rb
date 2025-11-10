# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::Globus do
  let(:service) { described_class.new }
  let(:druid) { 'bf070wx6289' }
  let(:prefixed_druid) { "druid:#{druid}" }

  let!(:purl_object) { create(:purl, druid: prefixed_druid) }

  let(:globus_pathname) { 'tmp/stacks/globus' }

  let(:object) { VersionedFilesService::Object.new(druid) }
  let(:versions_path) { object.versions_path }
  let(:globus_object_path) { "#{globus_pathname}/bf/070/wx/6289" }

  let(:cocina_object) do
    build(:dro_with_metadata, id: prefixed_druid).new(access: { view: 'world', download: 'world' }, structural:
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

  let(:s3_bucket) { Aws::S3::Bucket.new(Settings.s3.bucket, client: s3_client) }
  let(:s3_client) { S3ClientFactory.create_client }

  before do
    FileUtils.rm_rf(globus_pathname)
    allow(Settings.filesystems).to receive_messages(globus_root: globus_pathname)
  end

  after do
    FileUtils.rm_rf(globus_pathname)
    s3_bucket.clear!
  end

  describe '#link_all_druids' do
    before do
      # Just test one druid, but make sure we can read the list.
      allow(Settings.globus).to receive(:druid_list).and_return([druid])

      manifest = { head: 2 }
      s3_client.put_object(bucket: Settings.s3.bucket,
                           key: "#{versions_path}/versions.json",
                           body: manifest.to_json)

      cocina_json = create(:public_json, purl: purl_object).data
      s3_client.put_object(bucket: Settings.s3.bucket,
                           key: "#{versions_path}/cocina.json",
                           body: cocina_json)

      write_version(content_path: object.content_path, versions_path: versions_path, cocina_object: cocina_object)
    end

    it 'creates copies in the globus directory' do
      described_class.new.link_druid(druid)

      expect(File.read("#{globus_object_path}/file2.txt")).to eq 'file2.txt'
      expect(File.read("#{globus_object_path}/files/file2.txt")).to eq 'files/file2.txt'
    end
  end
end
