class CreateMembers < ActiveRecord::Migration[7.0]
  def change
    create_table :members do |t|
      t.bigint :parent_id
      t.string :name
      t.date :date_of_birth

      t.timestamps
    end
  end
end
