require 'rails_helper'

RSpec.describe ReleaseTag do
  let(:purl) { create(:purl, :with_release_tags) }

  describe '#release_tags' do
    it 'reads the data' do
      tags = purl.release_tags.to_h { |tag| [tag.name, tag.release_type] }
      expect(tags).to include('PURL sitemap' => true, 'Searchworks' => true)
    end
  end
end
