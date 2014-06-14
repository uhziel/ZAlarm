class CreateAlarms < ActiveRecord::Migration
  def up
    create_table :alarms do |t|
      t.string :title
      t.text :body
      t.timestamps
    end
    Alarm.create(title: "test first", body: "hello")
    Alarm.create(title: "test second", body: "hello")
    Alarm.create(title: "test three", body: "hello")
  end

  def down
    drop_table :alarms
  end
end
