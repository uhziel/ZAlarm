class ChangeAlarms < ActiveRecord::Migration
  def up
    change_table :alarms do |t|
      t.remove :body
      t.datetime :alarm_time
    end
  end

  def down
    change_table :alarms do |t|
      t.text :body
      t.remove :alarm_time
    end
  end
end
