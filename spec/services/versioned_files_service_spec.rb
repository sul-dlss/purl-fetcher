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

  before do
    allow(Settings.filesystems).to receive_messages(stacks_root: stacks_pathname, purl_root: purl_pathname)
    FileUtils.rm_rf(stacks_pathname)
    FileUtils.rm_rf(purl_pathname)
  end

  after do
    FileUtils.rm_rf(stacks_pathname)
    FileUtils.rm_rf(purl_pathname)
  end

  describe '#update' do
    let(:access_transfer_stage) { 'tmp/access-transfer-stage' }
    let(:version_metadata) { VersionedFilesService::VersionsManifest::VersionMetadata.new(version: 1, state: 'available', date: DateTime.now) }

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
          service.update(version: 1, version_metadata:, cocina: dro, file_transfers:)
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
          service.update(version: 1, version_metadata:, cocina: dro, file_transfers:)

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
          expect(File.read("#{versions_path}/public.1.xml")).to include 'publicObject'
          expect("#{versions_path}/public.xml").to link_to("#{versions_path}/public.1.xml")

          # Writes version manifest
          expect(VersionedFilesService::VersionsManifest.read("#{versions_path}/versions.json").manifest).to include(
            versions: { 1 => { state: 'available', date: version_metadata.date.iso8601 } },
            head: 1
          )

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

        let(:initial_version_metadata) { VersionedFilesService::VersionsManifest::VersionMetadata.new(1, false, DateTime.now) }

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
          write_version(content_path:, versions_path:, stacks_object_path:, cocina_object: initial_dro, version: 1, version_metadata: initial_version_metadata)
        end

        it 'writes content files and metadata' do
          service.update(version: 2, version_metadata:, cocina: dro, file_transfers:)

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
          expect(VersionedFilesService::VersionsManifest.read("#{versions_path}/versions.json").manifest).to include(
            versions: {
              1 => { state: 'available', date: initial_version_metadata.date.iso8601 },
              2 => { state: 'available', date: version_metadata.date.iso8601 }
            },
            head: 2
          )

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

        let(:initial_version_metadata) { VersionedFilesService::VersionsManifest::VersionMetadata.new(1, false, DateTime.now) }

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
          write_version(content_path:, versions_path:, stacks_object_path:, cocina_object: initial_dro, version: 1, version_metadata: initial_version_metadata)
        end

        it 'writes content files and metadata' do
          service.update(version: 1, version_metadata:, cocina: dro, file_transfers: {})

          # Retains unchanged content files
          expect(File.read("#{content_path}/3e25960a79dbc69b674cd4ec67a72c62")).to eq 'file2.txt'

          # Deletes unused content files
          expect(File.exist?("#{content_path}/327d41a48b459a2807d750324bd864ce")).to be false

          # Writes metadata
          expect(File.read("#{versions_path}/cocina.1.json")).to eq dro.to_json
          expect("#{versions_path}/cocina.json").to link_to("#{versions_path}/cocina.1.json")
          expect(File.read("#{versions_path}/public.1.xml")).to include 'publicObject'
          expect("#{versions_path}/public.xml").to link_to("#{versions_path}/public.1.xml")

          # Writes version manifest
          expect(VersionedFilesService::VersionsManifest.read("#{versions_path}/versions.json").manifest).to include(
            versions: {
              1 => { state: 'available', date: version_metadata.date.iso8601 }
            },
            head: 1
          )
        end
      end

      context 'when a collection' do
        let(:collection) { build(:collection_with_metadata, id: druid).new(access: { view: 'world' }) }

        it 'writes content files and metadata' do
          service.update(version: 1, version_metadata:, cocina: collection, file_transfers: {})

          expect(File.exist?(content_path)).to be false

          # Writes metadata
          expect(File.read("#{versions_path}/cocina.1.json")).to eq collection.to_json
          expect("#{versions_path}/cocina.json").to link_to("#{versions_path}/cocina.1.json")
          expect(File.read("#{versions_path}/public.1.xml")).to include 'publicObject'
          expect("#{versions_path}/public.xml").to link_to("#{versions_path}/public.1.xml")

          # Writes version manifest
          expect(VersionedFilesService::VersionsManifest.read("#{versions_path}/versions.json").manifest).to include(
            versions: {
              1 => { state: 'available', date: version_metadata.date.iso8601 }
            },
            head: 1
          )
        end
      end
    end
  end

  describe '#withdraw' do
    let(:action) { instance_double(VersionedFilesService::WithdrawAction, call: nil) }

    before do
      allow(VersionedFilesService::WithdrawAction).to receive(:new).and_return(action)
      allow(VersionedFilesService::Lock).to receive(:with_lock).and_yield
    end

    it 'invokes the withdraw action' do
      expect(service.withdraw(version: 1)).to be_nil

      expect(VersionedFilesService::WithdrawAction).to have_received(:new).with(version: 1, withdrawn: true, object: VersionedFilesService::Object)
      expect(VersionedFilesService::Lock).to have_received(:with_lock).with(VersionedFilesService::Object)
    end
  end
end
