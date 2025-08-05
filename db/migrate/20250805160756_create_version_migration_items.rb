class CreateVersionMigrationItems < ActiveRecord::Migration[8.0]
  def change
    create_table :version_migration_items do |t|
      t.string :druid, null: false
      t.string :status, null: false, default: 'not_analyzed'

      t.timestamps
    end
    add_index :version_migration_items, :druid, unique: true
    add_index :version_migration_items, :status
  end
end
