class Block < ActiveRecord::Base
  def do_work(*args)
    block = Block.first
    block.name = "Charlie"
    block.color = "Black"
    block.save
  end
end

class CreateBlocks < ActiveRecord::Migration
  def change
    create_table :blocks do |t|
      t.string :name
      t.string :color
      t.timestamps
    end
  end
end
