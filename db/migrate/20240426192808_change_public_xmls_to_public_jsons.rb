class ChangePublicXmlsToPublicJsons < ActiveRecord::Migration[7.1]
  def change
    rename_table :public_xmls, :public_jsons
  end
end
