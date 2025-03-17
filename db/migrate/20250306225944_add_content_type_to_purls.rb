class AddContentTypeToPurls < ActiveRecord::Migration[8.0]
  def change
    add_column :purls, :content_type, :string
  end
end
