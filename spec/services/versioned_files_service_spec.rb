# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService do
  let(:service) { described_class.new(druid:) }
  let(:druid) { 'druid:bc123df4567' }

  let(:purl_pathname) { 'tmp/purl_root' }
  let(:stacks_pathname) { 'tmp/stacks' }

  let(:content_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/content" }
  let(:versions_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions" }
  let(:stacks_object_path) { "#{stacks_pathname}/bc/123/df/4567" }

  let(:public_xml) { 'public xml' }

  before do
    allow(Settings.filesystems).to receive_messages(stacks_root: stacks_pathname, purl_root: purl_pathname)
    FileUtils.rm_rf(stacks_pathname)
    FileUtils.rm_rf(purl_pathname)
  end

  after do
    FileUtils.rm_rf(stacks_pathname)
    FileUtils.rm_rf(purl_pathname)
  end

  describe '#head_version' do
    context 'when the manifest has the head version' do
      before do
        FileUtils.mkdir_p("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions")
        manifest = { head: 3 }
        File.write("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions/versions.json", manifest.to_json)
      end

      it 'returns the head version' do
        expect(service.head_version).to eq(3)
      end
    end

    context 'when the version manifest does not exist' do
      it 'raises UnknownVersionError' do
        expect { service.head_version }.to raise_error(VersionedFilesService::UnknowVersionError, 'Head version not found')
      end
    end
  end

  describe '#version?' do
    context 'when the version manifest exists' do
      before do
        FileUtils.mkdir_p("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions")
        manifest = { versions: { 1 => { withdrawn: false, date: '2022-06-26T10:06:45−07:00' } } }
        File.write("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions/versions.json", manifest.to_json)
      end

      context 'when a version' do
        it 'returns true' do
          expect(service.version?(version: 1)).to be true
        end
      end

      context 'when not a version' do
        it 'returns false' do
          expect(service.version?(version: 2)).to be false
        end
      end
    end

    context 'when the version manifest does not exist' do
      it 'returns false' do
        expect(service.version?(version: 1)).to be false
      end
    end
  end

  describe '#version_metadata_for' do
    context 'when the version manifest exists' do
      before do
        FileUtils.mkdir_p("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions")
        manifest = { versions: { 1 => { withdrawn: false, date: '2022-06-26T10:06:45+07:00' } } }
        File.write("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions/versions.json", manifest.to_json)
      end

      context 'when a version' do
        it 'returns version metadata' do
          expect(service.version_metadata_for(version: 1)).to eq VersionedFilesService::VersionMetadata.new(false, DateTime.iso8601('2022-06-26T10:06:45+07:00'))
        end
      end

      context 'when not a version' do
        it 'raises UnknownVersionError' do
          expect { service.version_metadata_for(version: 2) }.to raise_error(VersionedFilesService::UnknowVersionError, 'Version 2 not found')
        end
      end
    end

    context 'when the version manifest does not exist' do
      it 'raises UnknownVersionError' do
        expect { service.version_metadata_for(version: 1) }.to raise_error(VersionedFilesService::UnknowVersionError, 'Version 1 not found')
      end
    end
  end

  describe '#withdraw' do
    context 'when the version manifest exists' do
      let(:versions_manifest) { JSON.parse(File.read(versions_manifest_path)).with_indifferent_access }

      let(:versions_manifest_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions/versions.json" }

      before do
        FileUtils.mkdir_p(File.dirname(versions_manifest_path))
        manifest = { versions: { 1 => { withdrawn: false, date: '2022-06-26T10:06:45+07:00' } } }
        File.write(versions_manifest_path, manifest.to_json)
      end

      context 'when withdrawing' do
        it 'sets withdrawn to true' do
          service.withdraw(version: 1)
          expect(service.version_metadata_for(version: 1).withdrawn?).to be true
          expect(versions_manifest[:versions]['1'][:withdrawn]).to be true
        end
      end

      context 'when unwithdrawing' do
        it 'sets withdrawn to false' do
          service.withdraw(version: 1, withdrawn: false)
          expect(service.version_metadata_for(version: 1).withdrawn?).to be false
          expect(versions_manifest[:versions]['1'][:withdrawn]).to be false
        end
      end

      context 'when not a version' do
        it 'raises UnknownVersionError' do
          expect { service.withdraw(version: 2) }.to raise_error(VersionedFilesService::UnknowVersionError, 'Version 2 not found')
        end
      end
    end

    context 'when the version manifest does not exist' do
      it 'raises UnknownVersionError' do
        expect { service.withdraw(version: 1) }.to raise_error(VersionedFilesService::UnknowVersionError, 'Version 1 not found')
      end
    end
  end

  describe '#content_mds5' do
    context 'when content files' do
      let(:content_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/content" }

      before do
        FileUtils.mkdir_p(content_path)
        FileUtils.touch("#{content_path}/41446aec93ba8d401a33b46679a7dcaa")
        FileUtils.touch("#{content_path}/dcd10eb5c49038ba0a6edfcf18b6877d")
      end

      it 'returns the content md5s' do
        expect(service.content_md5s.sort).to eq ['41446aec93ba8d401a33b46679a7dcaa', 'dcd10eb5c49038ba0a6edfcf18b6877d']
      end
    end

    context 'when content directory does not exist' do
      it 'returns empty array' do
        expect(service.content_md5s).to eq []
      end
    end
  end

  describe '#update' do
    let(:access_transfer_stage) { 'tmp/access-transfer-stage' }
    let(:version_metadata) { VersionedFilesService::VersionMetadata.new(false, DateTime.now) }

    before do
      FileUtils.mkdir_p(access_transfer_stage)
      allow(Settings.filesystems).to receive(:transfer).and_return(access_transfer_stage)
    end

    after do
      FileUtils.rm_rf(access_transfer_stage)
    end

    context 'when missing files' do
      let(:dro) { build(:dro_with_metadata, id: druid).new(structural:, access: { view: 'world', download: 'world' }) }

      let(:structural) do
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
        )
      end

      let(:file_transfers) { { 'file2.txt' => 'd7e54aed-c0c4-48af-af93-bc673f079f9a', 'files/file2.txt' => '7f807e3c-4cde-4b6d-8e76-f24455316a01' } }

      before do
        FileUtils.touch("#{access_transfer_stage}/d7e54aed-c0c4-48af-af93-bc673f079f9a")
      end

      it 'raises an error' do
        expect do
          service.update(version: '1', version_metadata:, cocina: dro, public_xml:,
                         file_transfers:)
        end.to raise_error(VersionedFilesService::BadFileTransferError, 'Transfer file for files/file2.txt not found')
      end

      context 'when writing first version' do
        let(:dro) { build(:dro_with_metadata, id: druid).new(structural:, access: { view: 'world', download: 'world' }) }

        let(:structural) do
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
                      label: 'not shelved file',
                      filename: 'not_shelved.txt',
                      version: 1,
                      hasMessageDigests: [
                        { type: 'md5', digest: '4f25960a79dbc69b674cd4ec67a72c73' }
                      ],
                      administrative: {
                        publish: false,
                        shelve: false
                      }
                    ),
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
          )
        end

        let(:file_transfers) { { 'file2.txt' => 'd7e54aed-c0c4-48af-af93-bc673f079f9a', 'files/file2.txt' => '7f807e3c-4cde-4b6d-8e76-f24455316a01' } }

        before do
          write_file_transfers(file_transfers:, access_transfer_stage:)
        end

        it 'writes content files and metadata' do
          service.update(version: '1', version_metadata:, cocina: dro, public_xml:,
                         file_transfers:)

          # Writes content files
          expect(File.read("#{content_path}/3e25960a79dbc69b674cd4ec67a72c62")).to eq 'file2.txt'
          expect(File.read("#{content_path}/5997de4d5abb55f21f652aa61b8f3aaf")).to eq 'files/file2.txt'

          # Deletes transfer files
          file_transfers.each_value do |transfer_uuid|
            expect(File.exist?("#{access_transfer_stage}/#{transfer_uuid}")).to be false
          end

          # Writes metadata
          expect(File.read("#{versions_path}/cocina.1.json")).to eq dro.to_json
          expect("#{versions_path}/cocina.json").to link_to("#{versions_path}/cocina.1.json")
          expect(File.read("#{versions_path}/public.1.xml")).to eq public_xml
          expect("#{versions_path}/public.xml").to link_to("#{versions_path}/public.1.xml")

          # Writes version manifest
          expect(File.read("#{versions_path}/versions.json")).to eq({ versions: { '1': { withdrawn: false, date: version_metadata.date.iso8601 } }, head: '1' }.to_json)

          # Symlinks to stacks filesystem
          expect("#{stacks_object_path}/file2.txt").to link_to("#{content_path}/3e25960a79dbc69b674cd4ec67a72c62")
          expect("#{stacks_object_path}/files/file2.txt").to link_to("#{content_path}/5997de4d5abb55f21f652aa61b8f3aaf")
        end
      end

      context 'when writing subsequent version' do
        let(:initial_dro) do
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
                    label: 'the to be removed file',
                    filename: 'file1.txt',
                    version: 1,
                    hasMessageDigests: [
                      { type: 'md5', digest: '327d41a48b459a2807d750324bd864ce' }
                    ],
                    administrative: {
                      publish: true,
                      shelve: true
                    }
                  ),
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

        let(:initial_version_metadata) { VersionedFilesService::VersionMetadata.new(false, DateTime.now) }

        let(:dro) { build(:dro_with_metadata, id: druid).new(structural:, access: { view: 'world', download: 'world' }) }

        # One new file (file3.txt), one changed file (file2.txt), one unchanged file (files/file2.txt), one deleted file (file1.txt).
        let(:structural) do
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
                        { type: 'md5', digest: '4f35960a79dbc69b674cd4ec67a72d73' }
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
                    ),
                    Cocina::Models::File.new(
                      externalIdentifier: '1234',
                      type: Cocina::Models::ObjectType.file,
                      label: 'the new file',
                      filename: 'file3.txt',
                      version: 1,
                      hasMessageDigests: [
                        { type: 'md5', digest: '6007de4d5abb55f21f652aa61b8f3bbg' }
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
          )
        end

        # Transferring one new file (file3.txt) and one changed file (file2.txt).
        let(:file_transfers) { { 'file2.txt' => 'e8f54aed-c0c4-48af-af93-bc673f079f0b', 'file3.txt' => '7f807e3c-4cde-4b6d-8e76-f24455316a01' } }

        before do
          write_file_transfers(file_transfers:, access_transfer_stage:)
          write_version(content_path:, versions_path:, stacks_object_path:, cocina_object: initial_dro, public_xml:, version: '1', version_metadata: initial_version_metadata)
        end

        it 'writes content files and metadata' do
          service.update(version: '2', version_metadata:, cocina: dro, public_xml:,
                         file_transfers:)

          # Writes new content files
          expect(File.read("#{content_path}/6007de4d5abb55f21f652aa61b8f3bbg")).to eq 'file3.txt'
          expect(File.read("#{content_path}/4f35960a79dbc69b674cd4ec67a72d73")).to eq 'file2.txt'

          # Retains unchanged content files
          expect(File.read("#{content_path}/327d41a48b459a2807d750324bd864ce")).to eq 'file1.txt'
          expect(File.read("#{content_path}/3e25960a79dbc69b674cd4ec67a72c62")).to eq 'file2.txt'
          expect(File.read("#{content_path}/5997de4d5abb55f21f652aa61b8f3aaf")).to eq 'files/file2.txt'

          # Deletes transfer files
          file_transfers.each_value do |transfer_uuid|
            expect(File.exist?("#{access_transfer_stage}/#{transfer_uuid}")).to be false
          end

          # Writes metadata
          expect(File.exist?("#{versions_path}/cocina.1.json")).to be true
          expect(File.read("#{versions_path}/cocina.2.json")).to eq dro.to_json
          expect("#{versions_path}/cocina.json").to link_to("#{versions_path}/cocina.2.json")
          expect(File.exist?("#{versions_path}/public.1.xml")).to be true
          expect("#{versions_path}/public.xml").to link_to("#{versions_path}/public.2.xml")

          # Writes version manifest
          expect(File.read("#{versions_path}/versions.json")).to eq({
            versions: {
              '1': { withdrawn: false, date: initial_version_metadata.date.iso8601 },
              '2': { withdrawn: false, date: version_metadata.date.iso8601 }
            },
            head: '2'
          }.to_json)

          # Symlinks to stacks filesystem
          expect(File.exist?("#{stacks_object_path}/file1.txt")).to be false
          expect("#{stacks_object_path}/file2.txt").to link_to("#{content_path}/4f35960a79dbc69b674cd4ec67a72d73")
          expect("#{stacks_object_path}/files/file2.txt").to link_to("#{content_path}/5997de4d5abb55f21f652aa61b8f3aaf")
          expect("#{stacks_object_path}/file3.txt").to link_to("#{content_path}/6007de4d5abb55f21f652aa61b8f3bbg")
        end
      end

      context 'when overwriting a version' do
        let(:initial_dro) do
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
                      label: 'the to be removed file',
                      filename: 'file1.txt',
                      version: 1,
                      hasMessageDigests: [
                        { type: 'md5', digest: '327d41a48b459a2807d750324bd864ce' }
                      ],
                      administrative: {
                        publish: true,
                        shelve: true
                      }
                    ),
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
                    )
                  ]
                )
              )
            ]
          ))
        end

        let(:initial_version_metadata) { VersionedFilesService::VersionMetadata.new(false, DateTime.now) }

        let(:dro) { build(:dro_with_metadata, id: druid).new(structural:, access: { view: 'world', download: 'world' }) }

        # One one unchanged file (file2.txt), one deleted file (file1.txt).
        let(:structural) do
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
                    )
                  ]
                )
              )
            ]
          )
        end

        before do
          write_version(content_path:, versions_path:, stacks_object_path:, cocina_object: initial_dro, public_xml:, version: '1', version_metadata: initial_version_metadata)
        end

        it 'writes content files and metadata' do
          service.update(version: 1, version_metadata:, cocina: dro, public_xml:,
                         file_transfers: {})

          # Retains unchanged content files
          expect(File.read("#{content_path}/3e25960a79dbc69b674cd4ec67a72c62")).to eq 'file2.txt'

          # Deletes unused content files
          expect(File.exist?("#{content_path}/327d41a48b459a2807d750324bd864ce")).to be false

          # Writes metadata
          expect(File.read("#{versions_path}/cocina.1.json")).to eq dro.to_json
          expect("#{versions_path}/cocina.json").to link_to("#{versions_path}/cocina.1.json")
          expect(File.read("#{versions_path}/public.1.xml")).to eq public_xml
          expect("#{versions_path}/public.xml").to link_to("#{versions_path}/public.1.xml")

          # Writes version manifest
          expect(File.read("#{versions_path}/versions.json")).to eq({
            versions: {
              '1': { withdrawn: false, date: version_metadata.date.iso8601 }
            },
            head: 1
          }.to_json)
        end
      end

      context 'when a collection' do
        let(:collection) { build(:collection_with_metadata, id: druid).new(access: { view: 'world' }) }

        it 'writes content files and metadata' do
          service.update(version: 1, version_metadata:, cocina: collection, public_xml:,
                         file_transfers: {})

          expect(File.exist?(content_path)).to be false

          # Writes metadata
          expect(File.read("#{versions_path}/cocina.1.json")).to eq collection.to_json
          expect("#{versions_path}/cocina.json").to link_to("#{versions_path}/cocina.1.json")
          expect(File.read("#{versions_path}/public.1.xml")).to eq public_xml
          expect("#{versions_path}/public.xml").to link_to("#{versions_path}/public.1.xml")

          # Writes version manifest
          expect(File.read("#{versions_path}/versions.json")).to eq({
            versions: {
              '1': { withdrawn: false, date: version_metadata.date.iso8601 }
            },
            head: 1
          }.to_json)
        end
      end
    end
  end

  describe '#delete' do
    context 'when not the head' do
      before do
        FileUtils.mkdir_p(versions_path.to_s)
        File.write("#{versions_path}/versions.json", { head: '2', versions: { '1': {}, '2': {} } }.to_json)
      end

      it 'raises an error' do
        expect { service.delete(version: 1) }.to raise_error(VersionedFilesService::Error, 'Only head version can be deleted')
      end
    end

    context 'when deleting a version that does not exist' do
      before do
        FileUtils.mkdir_p(versions_path.to_s)
        File.write("#{versions_path}/versions.json", { head: '1', versions: { '1': {} } }.to_json)
      end

      it 'raises an error' do
        expect { service.delete(version: 2) }.to raise_error(VersionedFilesService::UnknowVersionError, 'Version 2 not found')
      end
    end

    context 'when deleting a version 1 head' do
      let(:initial_dro) do
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

      let(:initial_version_metadata) { VersionedFilesService::VersionMetadata.new(false, DateTime.now) }

      before do
        write_version(content_path:, versions_path:, stacks_object_path:, cocina_object: initial_dro, public_xml:, version: 1, version_metadata: initial_version_metadata)
      end

      it 'update content files and metadata' do
        service.delete(version: 1)
        # Deletes content files
        expect(File.exist?("#{content_path}/3e25960a79dbc69b674cd4ec67a72c62")).to be false
        expect(File.exist?("#{content_path}/5997de4d5abb55f21f652aa61b8f3aaf")).to be false

        # Deletes metadata
        expect(File.exist?("#{versions_path}/cocina.1.json")).to be false
        expect(File.exist?("#{versions_path}/cocina.json")).to be false
        expect(File.exist?("#{versions_path}/public.1.xml")).to be false
        expect(File.exist?("#{versions_path}/public.xml")).to be false

        # Writes version manifest
        expect(File.read("#{versions_path}/versions.json")).to eq({
          versions: {}
        }.to_json)

        # Deletes symlinks to stacks filesystem
        expect(File.exist?("#{stacks_object_path}/file2.txt")).to be false
        expect(File.exist?("#{stacks_object_path}/files/file2.txt")).to be false
      end
    end

    context 'when deleting a subsequent version head' do
      let(:initial_dro) do
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
                  )
                ]
              )
            )
          ]
        ))
      end

      let(:version_2_dro) do
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
                    label: 'a file only in version 2',
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

      let(:initial_version_metadata) { VersionedFilesService::VersionMetadata.new(false, DateTime.now) }
      let(:version_2_metadata) { VersionedFilesService::VersionMetadata.new(false, DateTime.now) }

      before do
        write_version(content_path:, versions_path:, stacks_object_path:, cocina_object: initial_dro, public_xml:, version: '1', version_metadata: initial_version_metadata)
        write_version(content_path:, versions_path:, stacks_object_path:, cocina_object: version_2_dro, public_xml:, version: '2', version_metadata: version_2_metadata)
        File.write("#{versions_path}/versions.json", {
          versions: {
            1 => { withdrawn: false, date: initial_version_metadata.date.iso8601 },
            2 => { withdrawn: false, date: version_2_metadata.date.iso8601 }
          },
          head: 2
        }.to_json)
      end

      it 'update content files and metadata' do
        service.delete(version: 2)
        # Deletes content files
        expect(File.exist?("#{content_path}/3e25960a79dbc69b674cd4ec67a72c62")).to be true
        expect(File.exist?("#{content_path}/5997de4d5abb55f21f652aa61b8f3aaf")).to be false

        # Deletes metadata
        expect(File.read("#{versions_path}/cocina.1.json")).to eq initial_dro.to_json
        expect("#{versions_path}/cocina.json").to link_to("#{versions_path}/cocina.1.json")
        expect(File.read("#{versions_path}/public.1.xml")).to eq public_xml
        expect("#{versions_path}/public.xml").to link_to("#{versions_path}/public.1.xml")
        expect(File.exist?("#{versions_path}/cocina.2.json")).to be false
        expect(File.exist?("#{versions_path}/public.2.xml")).to be false

        # Writes version manifest
        expect(File.read("#{versions_path}/versions.json")).to eq({
          versions: {
            '1' => { withdrawn: false, date: initial_version_metadata.date.iso8601 }
          },
          head: 1
        }.to_json)

        # Deletes symlinks to stacks filesystem
        expect("#{stacks_object_path}/file2.txt").to link_to("#{content_path}/3e25960a79dbc69b674cd4ec67a72c62")
        expect(File.exist?("#{stacks_object_path}/files/file2.txt")).to be false
      end
    end
  end

  describe '#stacks_object_path' do
    let(:path) { service.stacks_object_path.to_s }

    it 'returns the expected path' do
      expect(path).to eq("#{stacks_pathname}/bc/123/df/4567")
    end
  end

  describe '#files_by_md5' do
    context 'when deleting a subsequent version head' do
      let(:initial_dro) do
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
                    label: 'a file only in version 1',
                    filename: 'files/file0.txt',
                    version: 1,
                    hasMessageDigests: [
                      { type: 'md5', digest: '3497de4d5abb55f21f652aa61b8f3abd' }
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

      let(:version_2_dro) do
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
                    label: 'a file only in version 2',
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
        write_version(content_path:, versions_path:, stacks_object_path:, cocina_object: initial_dro, version: '1')
        write_version(content_path:, versions_path:, stacks_object_path:, cocina_object: version_2_dro, version: '2')
        File.write("#{versions_path}/versions.json", {
          versions: {
            1 => { withdrawn: false, date: DateTime.now.iso8601 },
            2 => { withdrawn: false, date: DateTime.now.iso8601 }
          },
          head: '2'
        }.to_json)
      end

      it 'returns array of files by md5' do
        expect(service.files_by_md5).to eq [
          { "3e25960a79dbc69b674cd4ec67a72c62" => "file2.txt" },
          { "3497de4d5abb55f21f652aa61b8f3abd" => "files/file0.txt" },
          { "5997de4d5abb55f21f652aa61b8f3aaf" => "files/file2.txt" }
        ]
      end
    end
  end
end
