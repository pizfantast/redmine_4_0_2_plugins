class AddColumnsToCharts < ActiveRecord::Migration[5.0]
  def change
    add_column :charts, :range_integer, :integer, :default => 30
    add_column :charts, :range_type, :string, :default => 'days'
  end
end
