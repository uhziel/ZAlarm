class CreateAlarms < ActiveRecord::Migration
  def up
    create_table :alarms do |t|
      t.string :title
      t.text :body
      t.timestamps
    end
  end

  def down
    drop_table :alarms
  end
end
