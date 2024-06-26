# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OcflMigrator do
  subject(:migrator) { described_class.new(druid:) }

  let(:druid) { 'druid:mn023nf6127' }

  around do |example|
    example.run
  ensure
    FileUtils.rm_rf(Dir.glob("#{Settings.filesystems.ocfl_root}/*"))
  end

  describe '.migrate' do
    before { allow(described_class).to receive(:new).and_return(fake_instance) }

    let(:fake_instance) { instance_double(described_class, migrate: nil) }

    it 'invokes #migrate on a new instance' do
      described_class.migrate(druid:)
      expect(fake_instance).to have_received(:migrate).once
    end
  end

  describe '#migrate' do
    before do
      allow(OCFL::Object::DirectoryBuilder).to receive(:new).and_return(fake_builder)
      migrator.migrate
    end

    let(:fake_builder) { instance_double(OCFL::Object::DirectoryBuilder, copy_recursive: nil, save: nil) }

    it 'copies files from the stacks path' do
      expect(fake_builder).to have_received(:copy_recursive).with(/#{Settings.filesystems.stacks_root}/).once
    end

    it 'copies files from the purl path' do
      expect(fake_builder).to have_received(:copy_recursive).with(/#{Settings.filesystems.purl_root}/).once
    end

    it 'saves the OCFL object directory' do
      expect(fake_builder).to have_received(:save).once
    end
  end
end
