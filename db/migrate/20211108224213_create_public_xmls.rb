class CreatePublicXmls < ActiveRecord::Migration[6.1]
  def change
    create_table :public_xmls do |t|
      t.references :purl
      t.binary :data, limit: 16777216

      t.timestamps
    end
  end
end
