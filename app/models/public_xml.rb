class PublicXml < ApplicationRecord
  belongs_to :purl

  def data=(data)
    super(ActiveSupport::Gzip.compress(data))
  end

  def data
    ActiveSupport::Gzip.decompress(super)
  end
end
