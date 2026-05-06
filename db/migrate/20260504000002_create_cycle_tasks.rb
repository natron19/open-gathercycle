class CreateCycleTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :cycle_tasks, id: :uuid do |t|
      t.references :growth_cycle,      null: false, foreign_key: true, type: :uuid
      t.string     :phase,             null: false
      t.string     :title,             null: false
      t.string     :owner_type,        null: false
      t.string     :effort_estimate,   null: false
      t.string     :success_indicator, null: false
      t.boolean    :completed,         null: false, default: false
      t.integer    :position,          null: false, default: 0
      t.timestamps
    end

    add_index :cycle_tasks, :phase
    add_index :cycle_tasks, :completed
  end
end
