# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::StacksLinkAction do
  describe '#recursive_cleanup' do
    let(:action) { described_class.new(version: 1, object:) }

    let(:druid) { 'druid:bc123df4567' }
    let(:object) { instance_double(VersionedFilesService::Object, stacks_object_path: stacks_object_pathname, object_path: object_pathname) }

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

    let(:stacks_object_path) { 'tmp/purl_doc_cache/bc/123/df/4567' }
    let(:stacks_object_pathname) { Pathname.new(stacks_object_path) }
    let(:object_path) { "#{stacks_object_path}/bc123df4567" }
    let(:object_pathname) { Pathname.new(object_path) }

    before do
      FileUtils.mkdir_p(object_path)
      # These are the expected files.
      FileUtils.touch("#{stacks_object_path}/file2.txt")
      FileUtils.mkdir_p("#{stacks_object_path}/files")
      FileUtils.touch("#{stacks_object_path}/files/file2.txt")
      # These are the extra files.
      FileUtils.touch("#{stacks_object_path}/file1.txt")
      FileUtils.mkdir_p("#{stacks_object_path}/files2")
      FileUtils.touch("#{stacks_object_path}/files2/file1.txt")
      FileUtils.mkdir_p("#{stacks_object_path}/files3")

      allow(action).to receive(:shelve_file_map).and_return({
                                                              'file2.txt' => '3e25960a79dbc69b674cd4ec67a72c62',
                                                              'files/file2.txt' => '5997de4d5abb55f21f652aa61b8f3aaf'
                                                            })
    end

    after do
      FileUtils.rm_rf(stacks_object_path)
    end

    it 'deletes extra files and directories' do
      action.send(:recursive_cleanup, stacks_object_pathname)

      expect(File.exist?("#{stacks_object_path}/file2.txt")).to be true
      expect(File.exist?("#{stacks_object_path}/files/file2.txt")).to be true

      expect(File.exist?("#{stacks_object_path}/file1.txt")).to be false
      expect(Dir.exist?("#{stacks_object_path}/files2")).to be false
      expect(File.exist?("#{stacks_object_path}/files2/file1.txt")).to be false
      expect(Dir.exist?("#{stacks_object_path}/files3")).to be false

      expect(Dir.exist?(object_path)).to be true
    end
  end

  describe '#call' do
    let(:action) { described_class.new(version: 1, object:) }

    let(:druid) { "druid:#{bare_druid}" }
    let(:bare_druid) { 'bc123df4567' }
    let(:object) do
      instance_double(VersionedFilesService::Object, druid: bare_druid, stacks_object_path: stacks_object_pathname, object_path: object_pathname, content_path_for: Pathname.new(dummy_file_path))
    end

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

    let(:stacks_object_path) { 'tmp/purl_doc_cache/bc/123/df/4567' }
    let(:stacks_object_pathname) { Pathname.new(stacks_object_path) }
    let(:object_path) { "#{stacks_object_path}/bc123df4567" }
    let(:object_pathname) { Pathname.new(object_path) }
    let(:dummy_file_path) { "#{object_pathname}/contents/dummy_file.txt" }

    before do
      FileUtils.mkdir_p(object_path)
      FileUtils.mkdir_p("#{object_pathname}/contents")

      FileUtils.touch(dummy_file_path)

      allow(action).to receive(:shelve_file_map).and_return({
                                                              'file2.txt' => '3e25960a79dbc69b674cd4ec67a72c62',
                                                              'files/file2.txt' => '5997de4d5abb55f21f652aa61b8f3aaf',
                                                              'bc123df4567/invalid.json' => '3e25960a79dbc69b674cd4ec67a72c62',
                                                              'bc123df4567_1/valid.json' => '3e25960a79dbc69b674cd4ec67a72c62',
                                                              'bc123df4567' => '3e25960a79dbc69b674cd4ec67a72c62',
                                                              'bc123df4567_2' => '3e25960a79dbc69b674cd4ec67a72c62',
                                                              '/tmp/abc' => '3e25960a79dbc69b674cd4ec67a72c62'
                                                            })
    end

    after do
      FileUtils.rm_rf(stacks_object_path)
      FileUtils.rm_rf('/tmp/abc')
    end

    it 'does not create files that conflict with the AWFL layout' do
      allow(Honeybadger).to receive(:notify)

      action.call

      expect(File.exist?("#{stacks_object_path}/file2.txt")).to be true
      expect(File.exist?("#{stacks_object_path}/files/file2.txt")).to be true
      expect(File.exist?("#{stacks_object_path}/bc123df4567_1/valid.json")).to be true
      expect(File.exist?("#{stacks_object_path}/bc123df4567_2")).to be true

      expect(File.exist?("#{stacks_object_path}/bc123df4567/invalid.json")).to be false

      expect(Honeybadger).to have_received(:notify).with(%r{Skipping bc123df4567/invalid.json})
    end

    it 'does not create files that cause directory traversal' do
      allow(Honeybadger).to receive(:notify)

      action.call

      expect(File.exist?("/tmp/abc")).to be false

      expect(Honeybadger).to have_received(:notify).with(%r{Skipping /tmp/abc})
    end
  end
end
