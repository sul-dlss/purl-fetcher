class DropVersionMigrationItem < ActiveRecord::Migration[8.0]
  def change
    drop_table :version_migration_items
  end
end
