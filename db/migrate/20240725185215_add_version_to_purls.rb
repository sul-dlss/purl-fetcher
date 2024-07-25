class AddVersionToPurls < ActiveRecord::Migration[7.1]
  def change
    add_column :purls, :version, :integer
  end
end
