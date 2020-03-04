class AddUrnToClaims < ActiveRecord::Migration[6.0]
  def change
    add_column :claims, :urn, :string
  end
end
