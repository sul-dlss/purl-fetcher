# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::Object do
  let(:service) { described_class.new(druid) }
  let(:druid) { 'druid:bc123df4567' }

  let(:stacks_pathname) { 'tmp/stacks' }

  let(:content_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/content" }
  let(:versions_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions" }

  let(:public_xml) { 'public xml' }

  before do
    allow(Settings.filesystems).to receive_messages(stacks_root: stacks_pathname)
    FileUtils.rm_rf(stacks_pathname)
  end

  after do
    FileUtils.rm_rf(stacks_pathname)
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
      it 'returns nil' do
        expect(service.head_version).to be_nil
      end
    end
  end

  describe '#version?' do
    context 'when the version manifest exists' do
      before do
        FileUtils.mkdir_p("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions")
        manifest = { versions: { '1': { state: 'available', date: '2022-06-26T10:06:45−07:00' } } }
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
        manifest = { versions: { '1' => { state: 'available', date: '2022-06-26T10:06:45+07:00' } } }
        File.write("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions/versions.json", manifest.to_json)
      end

      context 'when a version' do
        it 'returns version metadata' do
          expect(service.version_metadata_for(version: 1)).to eq VersionedFilesService::VersionsManifest::VersionMetadata.new(version: 1, state: 'available',
                                                                                                                              date: DateTime.iso8601('2022-06-26T10:06:45+07:00'))
        end
      end

      context 'when not a version' do
        it 'raises UnknownVersionError' do
          expect { service.version_metadata_for(version: 2) }.to raise_error(VersionedFilesService::UnknownVersionError, 'Version 2 not found')
        end
      end
    end

    context 'when the version manifest does not exist' do
      it 'raises UnknownVersionError' do
        expect { service.version_metadata_for(version: 1) }.to raise_error(VersionedFilesService::UnknownVersionError, 'Version 1 not found')
      end
    end
  end

  describe '#withdraw' do
    context 'when the version manifest exists' do
      let(:versions_manifest) { JSON.parse(File.read(versions_manifest_path)).with_indifferent_access }

      let(:versions_manifest_path) { "#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions/versions.json" }

      before do
        FileUtils.mkdir_p(File.dirname(versions_manifest_path))
        manifest = { versions: { '1': { state: 'available', date: '2022-06-26T10:06:45+07:00' } } }
        File.write(versions_manifest_path, manifest.to_json)
      end

      context 'when withdrawing' do
        it 'sets withdrawn to true' do
          service.withdraw(version: 1)
          expect(service.version_metadata_for(version: 1).withdrawn?).to be true
          expect(versions_manifest[:versions]['1'][:state]).to eq 'withdrawn'
        end
      end

      context 'when unwithdrawing' do
        it 'sets withdrawn to false' do
          service.withdraw(version: 1, withdrawn: false)
          expect(service.version_metadata_for(version: 1).withdrawn?).to be false
          expect(versions_manifest[:versions]['1'][:state]).to eq 'available'
        end
      end

      context 'when not a version' do
        it 'raises UnknownVersionError' do
          expect { service.withdraw(version: 2) }.to raise_error(VersionedFilesService::UnknownVersionError, 'Version 2 not found')
        end
      end
    end

    context 'when the version manifest does not exist' do
      it 'raises UnknownVersionError' do
        expect { service.withdraw(version: 1) }.to raise_error(VersionedFilesService::UnknownVersionError, 'Version 1 not found')
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
                    label: 'a file only in version 1',
                    filename: 'files/file0.txt',
                    size: 15, # write_version uses the file name for the file content
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
                    label: 'a file only in version 2',
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
        write_version(content_path:, versions_path:, cocina_object: initial_dro, version: 1)
        write_version(content_path:, versions_path:, cocina_object: version_2_dro, version: 2)
        File.write("#{versions_path}/versions.json", {
          versions: {
            1 => { state: 'available', date: DateTime.now.iso8601 },
            2 => { state: 'available', date: DateTime.now.iso8601 }
          },
          head: '2'
        }.to_json)
      end

      it 'returns array of files by md5' do
        expect(service.file_details_by_md5).to eq [
          VersionedFilesService::Cocina::FileDetails.new(md5: '3e25960a79dbc69b674cd4ec67a72c62', filename: 'file2.txt', filesize: 9),
          VersionedFilesService::Cocina::FileDetails.new(md5: '3497de4d5abb55f21f652aa61b8f3abd', filename: 'files/file0.txt', filesize: 15),
          VersionedFilesService::Cocina::FileDetails.new(md5: '5997de4d5abb55f21f652aa61b8f3aaf', filename: 'files/file2.txt', filesize: 15)
        ]
      end
    end
  end
end
