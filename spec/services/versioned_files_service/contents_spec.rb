# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::Contents do
  let(:service) { described_class.new(paths: paths) }
  let(:paths) { VersionedFilesService::Paths.new(druid: druid) }
  let(:druid) { 'druid:bc123df4567' }
  let(:content_path_for) { Pathname.new(content_pathname).join(md5) }
  let(:content_pathname) { 'tmp/stacks_contents_spec/bc/123/df/4567/bc123df4567/content' }
  let(:md5) { '41446aec93ba8d401a33b46679a7dcaa' }
  let(:source_contents) { 'the quick brown fox' }
  let(:source_path) { Pathname.new('tmp/transfer_contents_spec/source') }
  let(:temp_path) { "#{content_path_for}.tmp" }

  before do
    allow(Settings.filesystems).to receive(:stacks_root).and_return('tmp/stacks_contents_spec')
    FileUtils.rm_rf('tmp/stacks_contents_spec')
    FileUtils.rm_rf('tmp/transfer_contents_spec')
    FileUtils.mkdir_p(source_path.dirname)
    File.write(source_path, source_contents)
  end

  after do
    FileUtils.rm_rf('tmp/stacks_contents_spec')
    FileUtils.rm_rf('tmp/transfer_contents_spec')
  end

  describe '#move_content' do
    subject(:move) { service.move_content(md5:, source_path:) }

    context 'when the destination does not exist' do
      it 'moves the source into the content path' do
        move
        expect(File.read(content_path_for)).to eq(source_contents)
      end

      it 'removes the source file' do
        move
        expect(File.exist?(source_path)).to be false
      end

      it 'does not leave a temp file behind' do
        move
        expect(File.exist?(temp_path)).to be false
      end
    end

    context 'when the destination already exists' do
      before do
        FileUtils.mkdir_p(content_path_for.dirname)
        File.write(content_path_for, 'already here')
      end

      it 'does not overwrite the existing destination' do
        move
        expect(File.read(content_path_for)).to eq('already here')
      end

      it 'does not remove the source' do
        move
        expect(File.exist?(source_path)).to be true
      end

      it 'does not leave a temp file behind' do
        move
        expect(File.exist?(temp_path)).to be false
      end
    end

    context 'when a temp file from a prior interrupted run exists' do
      before do
        FileUtils.mkdir_p(content_path_for.dirname)
        File.write(temp_path, 'partial garbage')
      end

      it 'removes the stale temp file before copying' do
        move
        expect(File.exist?(temp_path)).to be false
      end

      it 'writes the correct content to the destination' do
        move
        expect(File.read(content_path_for)).to eq(source_contents)
      end
    end

    context 'when the copy fails mid-stream (simulating a cross-filesystem copy interrupted)' do
      before do
        allow(IO).to receive(:copy_stream).and_raise(Interrupt)
      end

      it 'propagates the error' do
        expect { move }.to raise_error(Interrupt)
      end

      it 'does not create the destination' do
        expect { move }.to raise_error(Interrupt)
        expect(File.exist?(content_path_for)).to be false
      end

      it 'cleans up the partial temp file' do
        expect { move }.to raise_error(Interrupt)
        expect(File.exist?(temp_path)).to be false
      end

      it 'leaves the source in place for retry' do
        expect { move }.to raise_error(Interrupt)
        expect(File.exist?(source_path)).to be true
      end
    end
  end
end
