require 'rails'
require 'active_record/railtie'

migration_class = if ActiveRecord::Migration.respond_to?(:[])
                    ActiveRecord::Migration[4.2]
                  else
                    ActiveRecord::Migration
                  end

class CreateBlocks < migration_class
  def change
    create_table :blocks do |t|
      t.string :name
      t.string :color
      t.timestamps
    end
  end
end

class Block < ActiveRecord::Base
end
