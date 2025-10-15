# frozen_string_literal: true

class AddDescriptionAndNotesToExpense < ActiveRecord::Migration[8.0]
  def change
    add_column :expenses, :description, :string, null: false, default: ''
    add_column :expenses, :notes, :text
  end
end
