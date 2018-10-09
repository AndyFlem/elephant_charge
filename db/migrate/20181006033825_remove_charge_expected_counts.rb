class RemoveChargeExpectedCounts < ActiveRecord::Migration[5.0]
  def change
    remove_column :charges, :entries_expected
    remove_column :charges, :guards_expected
  end
end
