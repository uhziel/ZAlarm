class AddSyncFlag < ActiveRecord::Migration
  def up
    change_table :alarms do |t|
      t.datetime :sync_flag
    end
  end

  def down
    change_table :alarms do |t|
      t.remove :sync_flag
    end
end
end
