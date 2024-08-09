# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DarkenService do
  let(:service) { described_class.new(druid) }
  let(:druid) { 'druid:bc234fg4567' }
  let(:stacks_druid_path) { DruidTools::PurlDruid.new(druid, Settings.filesystems.stacks_root).pathname }

  before do
    FileUtils.mkdir_p(stacks_druid_path)
  end

  it 'removes the object from the stacks filesystem' do
    expect(File.exist?(stacks_druid_path)).to be true
    expect(File.exist?(stacks_druid_path.parent)).to be true
    service.call
    expect(File.exist?(stacks_druid_path.parent)).to be false
  end

  context 'when there are other object in the druid tree' do
    let(:second_druid) { 'druid:bc234fg1234' }
    let(:second_path) { DruidTools::PurlDruid.new(second_druid, Settings.filesystems.stacks_root).pathname }

    before do
      FileUtils.mkdir_p(second_path)
    end

    after do
      FileUtils.rm_rf(second_path)
    end

    it 'removes only the expected object from the stacks filesystem' do
      expect(File.exist?(stacks_druid_path)).to be true
      expect(File.exist?(second_path)).to be true
      service.call
      expect(File.exist?(stacks_druid_path)).to be false
      expect(File.exist?(second_path)).to be true
    end
  end
end
