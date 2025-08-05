require 'rails_helper'

RSpec.describe VersionMigrationItem do
  describe '.create_all' do
    before do
      Purl.create(druid: 'druid:dk120qp2074')
    end

    it 'creates a new VersionMigrationItem' do
      expect { described_class.create_all }.to change(described_class, :count).by(1)
      expect(described_class.last.status).to eq 'not_analyzed'
    end
  end
end
