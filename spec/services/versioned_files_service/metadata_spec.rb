# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionedFilesService::Metadata do
  describe '.deep_compact_blank' do
    subject { described_class.deep_compact_blank(input) }

    context 'with false values' do
      let(:input) do
        {
          administrative: {
            publish: true,
            sdrPreserve: false,
            shelve: true
          }
        }
      end

      it { is_expected.to eq(input) }
    end
  end
end
