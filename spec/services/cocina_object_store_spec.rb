require 'rails_helper'

RSpec.describe CocinaObjectStore do
  let(:druid) { 'druid:bc123df4567' }
  let!(:object) { create(:purl, druid: druid) }
  let(:cocina_json) { create(:public_json, purl: object).data }
  let(:s3_bucket) { Aws::S3::Bucket.new(Settings.s3.bucket, client: s3_client) }
  let(:s3_client) { S3ClientFactory.create_client }

  after do
    s3_bucket.clear!
  end

  describe '.find' do
    context 'when the cocina.json exists in the versioned stacks path' do
      before do
        # Create the file
        s3_client.put_object(
          bucket: Settings.s3.bucket,
          key: "bc/123/df/4567/bc123df4567/versions/versions.json",
          body: { head: 3 }.to_json
        )
        s3_client.put_object(
          bucket: Settings.s3.bucket,
          key: "bc/123/df/4567/bc123df4567/versions/cocina.3.json",
          body: cocina_json
        )
      end

      it 'returns a Cocina::Models::DROWithMetadata object' do
        result = described_class.find(druid)
        expect(result).to be_a(Cocina::Models::DROWithMetadata)
      end
    end
  end

  describe '.head_cocina_path' do
    let(:version_path) { "bc/123/df/4567/bc123df4567/versions" }
    let(:path) { described_class.head_cocina_path(druid).to_s }

    before do
      # create version manifest to find head version
      s3_client.put_object(
        bucket: Settings.s3.bucket,
        key: "bc/123/df/4567/bc123df4567/versions/versions.json",
        body: { head: 3 }.to_json
      )
    end

    after do
      s3_bucket.clear!
    end

    it 'returns the expected path' do
      expect(path).to eq("bc/123/df/4567/bc123df4567/versions/cocina.3.json")
    end
  end
end
