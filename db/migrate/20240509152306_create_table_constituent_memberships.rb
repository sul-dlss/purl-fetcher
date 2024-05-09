class CreateTableConstituentMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :constituent_memberships do |t|
      t.belongs_to :parent, null: false, foreign_key: { to_table: :purls }, type: :integer
      t.belongs_to :child, null: false, foreign_key:  { to_table: :purls }, type: :integer
      t.integer :sort_order, null: false

      t.timestamps
      t.index [:parent_id, :child_id], unique: true
    end
  end
end
