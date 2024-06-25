class PublicJson < ApplicationRecord
  belongs_to :purl

  def data=(data)
    super(ActiveSupport::Gzip.compress(data))
  end

  def data
    ActiveSupport::Gzip.decompress(super)
  end

  def cocina_hash
    JSON.parse(data)
  end

  # The purpose here is to tell DSA which files we currently have (across all versions)
  def files_by_md5
    file_sets = cocina_hash.dig('structural', 'contains')
    file_sets.flat_map do |fs|
      fs.dig('structural', 'contains').map do |file|
        md5_node = file.fetch('hasMessageDigests').find { |digest| digest.fetch('type') == 'md5' }
        { md5_node.fetch('digest') => file.fetch('filename') }
      end
    end
  end
end
