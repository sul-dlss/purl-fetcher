# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PurlCocinaUpdater do
  let(:updater) { described_class.new(purl, cocina) }

  let(:purl) { create(:purl) }
  let(:cocina) do
    build(:dro, id: purl.druid,
                type: Cocina::Models::ObjectType.image,
                collection_ids: ['druid:xb432gf1111'])
  end

  describe '#update' do
    before do
      allow(Honeybadger).to receive(:notify)
      updater.update
      purl.reload
    end

    it "updates the stored data" do
      expect(purl.cocina_object).to eq cocina
      expect(purl.public_json.data).to eq cocina.to_json
    end

    it "adds collection memberships" do
      expect(purl.collections.pluck(:druid)).to eq ["druid:xb432gf1111"]
      expect(purl.constituents).to be_empty
    end

    it "sets the content type" do
      expect(purl.content_type).to eq "image"
    end

    context 'when the data has constituents' do
      let(:cocina) do
        build(:dro, id: purl.druid).new(structural:)
      end

      let(:structural) do
        {
          contains: [],
          hasMemberOrders: [
            {
              members: ['druid:hj097bm8879'],
              viewingDirection: 'left-to-right'
            }
          ]
        }
      end

      it "adds constituent memberships" do
        expect(purl.constituents.pluck(:druid)).to eq ["druid:hj097bm8879"]
      end
    end

    context 'with a utf8mb4 string value' do
      let(:cocina) do
        build(:dro, id: purl.druid, title: "𒀒 is an odd symbol")
      end

      it 'logs a message' do
        expect(Honeybadger).to have_received(:notify).once
      end
    end
  end
end
