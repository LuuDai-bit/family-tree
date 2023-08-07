class AddLeftRightToMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :members, :count_left, :integer
    add_column :members, :count_right, :integer
    add_column :members, :group_id, :bigint
  end
end
