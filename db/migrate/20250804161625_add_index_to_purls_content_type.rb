class AddIndexToPurlsContentType < ActiveRecord::Migration[8.0]
  def change
    add_index :purls, :content_type
  end
end
