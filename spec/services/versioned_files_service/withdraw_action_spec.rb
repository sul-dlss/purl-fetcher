# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::WithdrawAction do
  let(:action) { described_class.new(object:, version:, withdrawn:) }

  let(:druid) { 'druid:bc123df4567' }
  let(:version) { 2 }
  let(:withdrawn) { true }

  let(:stacks_object_path) { 'tmp/stacks/bc/123/df/4567/bc123df4567' }
  let(:versions_path) { "#{stacks_object_path}/versions" }

  let(:object) do
    VersionedFilesService::Object.new(druid)
  end

  let(:versions_data) do
    {
      versions: {
        '1' => { withdrawn: true, date: DateTime.now.iso8601 },
        '2' => { withdrawn: false, date: DateTime.now.iso8601 },
        '3' => { withdrawn: false, date: DateTime.now.iso8601 }
      },
      head: 3
    }
  end

  before do
    FileUtils.mkdir_p(versions_path)
    File.write("#{versions_path}/versions.json", versions_data.to_json)
  end

  after do
    FileUtils.rm_rf(stacks_object_path)
  end

  context 'when version is head' do
    let(:version) { 3 }

    it 'raises an error' do
      expect { action.call }.to raise_error(VersionedFilesService::Error, 'Cannot withdraw head version')
    end
  end

  context 'when version does not exist' do
    let(:version) { 4 }

    it 'raises an error' do
      expect { action.call }.to raise_error(VersionedFilesService::Error, 'Version 4 not found')
    end
  end

  context 'when withdrawing' do
    it 'withdraws the version' do
      action.call

      versions_data = JSON.parse(File.read("#{versions_path}/versions.json"))
      expect(versions_data['versions']['2']['withdrawn']).to be true
    end
  end

  context 'when restoring' do
    let(:withdrawn) { false }
    let(:version) { 1 }

    it 'restores the version' do
      action.call

      versions_data = JSON.parse(File.read("#{versions_path}/versions.json"))
      expect(versions_data['versions']['1']['withdrawn']).to be false
    end
  end
end
