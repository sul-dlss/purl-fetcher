class AddDataTypeToPublicXml < ActiveRecord::Migration[7.0]
  def change
    add_column :public_xmls, :data_type, :string
  end
end
