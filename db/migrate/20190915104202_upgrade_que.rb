class UpgradeQue < ActiveRecord::Migration[6.0]
  def up
    Que.migrate!(version: 4)
  end
end
