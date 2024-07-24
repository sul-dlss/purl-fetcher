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
end
