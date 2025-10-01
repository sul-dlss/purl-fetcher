# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Publish::PublicCocinaGenerator do
  subject(:doc) { described_class.generate(cocina:) }

  let(:constituents) { [] }

  let(:cocina) do
    Cocina::Models.build({
                           type: "https://cocina.sul.stanford.edu/models/book",
                           externalIdentifier: druid,
                           label: "Test DRO",
                           version: 1,
                           access:,
                           administrative: { "hasAdminPolicy" => "druid:hy787xj5878" },
                           description:,
                           identification:,
                           structural:
                         })
  end
  let(:druid) { "druid:bc123df4567" }

  let(:access) { {} }
  let(:identification) { { sourceId: 'sul:123' } }
  let(:structural) { {} }
  let(:description) do
    { title: [{ value: 'stuff' }], purl: 'https://purl.stanford.edu/bc123df4567' }
  end

  describe '#generate' do
    context 'when the object is the constituent of a virtual object' do
      let(:constituents) { [{ id: 'druid:hj097bm8879', title: 'Test DRO' }] }

      before do
        allow(VirtualObject).to receive(:for).and_return(constituents)
      end

      it 'writes the relationships into cocina' do
        expect(doc.description.title.first.value).to eq 'stuff'
        expect(doc.description.purl).to eq 'https://purl.stanford.edu/bc123df4567'
        related_resource = doc.description.relatedResource.first
        expect(related_resource.title.first.value).to eq 'Test DRO'
        expect(related_resource.displayLabel).to eq 'Appears in'
        expect(related_resource.purl).to eq 'https://purl.stanford.edu/hj097bm8879'
      end
    end
  end
end
