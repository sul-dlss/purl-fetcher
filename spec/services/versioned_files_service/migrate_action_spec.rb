# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::MigrateAction do
  let(:action) { described_class.new(object:, version_metadata:) }

  let(:object) do
    VersionedFilesService::Object.new(druid)
  end

  let(:version_metadata) { VersionedFilesService::VersionMetadata.new(version: 1, withdrawn: false, date: DateTime.now) }

  let(:druid) { 'druid:bc123df4567' }

  let(:purl_pathname) { 'tmp/purl_root' }
  let(:stacks_pathname) { 'tmp/stacks' }

  let(:purl_object_path) { "#{purl_pathname}/bc/123/df/4567" }

  let(:content_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/content" }
  let(:versions_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions" }
  let(:stacks_object_path) { "#{stacks_pathname}/bc/123/df/4567" }

  let(:dro) do
    build(:dro_with_metadata, id: druid).new(access: { view: 'world', download: 'world' }, structural:
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
    allow(Settings.filesystems).to receive_messages(stacks_root: stacks_pathname, purl_root: purl_pathname)

    FileUtils.mkdir_p(stacks_object_path)
    File.write("#{stacks_object_path}/file2.txt", 'file2.txt')
    FileUtils.mkdir_p("#{stacks_object_path}/files")
    File.write("#{stacks_object_path}/files/file2.txt", 'files/file2.txt')

    FileUtils.mkdir_p(purl_object_path)
    File.write("#{purl_object_path}/cocina.json", dro.to_json)
    File.write("#{purl_object_path}/public", 'public xml')
    File.write("#{purl_object_path}/meta.json", 'meta json')
  end

  after do
    FileUtils.rm_rf(stacks_pathname)
    FileUtils.rm_rf(purl_pathname)
  end

  context 'when content files are missing' do
    before do
      File.delete("#{stacks_object_path}/file2.txt")
    end

    it 'raises' do
      expect { action.call }.to raise_error(VersionedFilesService::Error, 'Content file for file2.txt not found')
    end
  end

  it 'migrates to purl version layout' do
    action.call

    # Writes content files
    expect("#{content_path}/3e25960a79dbc69b674cd4ec67a72c62").to link_to("#{stacks_object_path}/file2.txt")
    expect("#{content_path}/5997de4d5abb55f21f652aa61b8f3aaf").to link_to("#{stacks_object_path}/files/file2.txt")

    # Writes metadata
    expect(File.read("#{versions_path}/cocina.1.json")).to eq dro.to_json
    expect("#{versions_path}/cocina.json").to link_to("#{versions_path}/cocina.1.json")
    expect(File.read("#{versions_path}/public.1.xml")).to eq "public xml"
    expect("#{versions_path}/public.xml").to link_to("#{versions_path}/public.1.xml")
    expect(File.read("#{versions_path}/meta.json")).to eq "meta json"

    # Writes version manifest
    expect(VersionedFilesService::VersionsManifest.read("#{versions_path}/versions.json").manifest).to include(
      versions: { 1 => { withdrawn: false, date: version_metadata.date.iso8601 } },
      head: 1
    )
  end
end
