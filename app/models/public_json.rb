class PublicJson < ApplicationRecord
  belongs_to :purl

  def data=(data)
    super(ActiveSupport::Gzip.compress(data))
  end

  def data
    ActiveSupport::Gzip.decompress(super)
  end

  def cocina_hash
    return {} unless data_type == 'cocina' # Legacy metadata (xml), doesn't set this

    JSON.parse(data)
  end
end
