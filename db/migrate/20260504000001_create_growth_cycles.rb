class CreateGrowthCycles < ActiveRecord::Migration[8.1]
  def change
    create_table :growth_cycles, id: :uuid do |t|
      t.references :user,              null: false, foreign_key: true, type: :uuid
      t.string     :organization_name, null: false
      t.string     :name,              null: false
      t.string     :time_period,       null: false
      t.string     :goal_description,  null: false
      t.text       :audience_description, null: false
      t.string     :status,            null: false, default: "pending"
      t.text       :gemini_raw
      t.timestamps
    end

    add_index :growth_cycles, :status
    add_index :growth_cycles, :created_at
  end
end
