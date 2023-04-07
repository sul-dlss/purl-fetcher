class CreateVirtualObjectConstituents < ActiveRecord::Migration[7.0]
  def change
    create_table :virtual_object_constituents do |t|
      t.references :purl, null: false, foreign_key: true
      t.string :has_member, null: false, index: true
      t.integer :ordinal, null: false
      t.index [:purl_id, :has_member], unique: true
      t.index [:purl_id, :ordinal], unique: true
      t.timestamps
    end
  end
end
