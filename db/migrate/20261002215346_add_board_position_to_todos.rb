# The Work board's own order: one list per status across every engagement, which people set by
# dragging (Todo positions per engagement stay as they are). Filled from the order the board
# showed before (due date, then position), so it looks the same until someone moves a card.
class AddBoardPositionToTodos < ActiveRecord::Migration[8.1]
  def up
    add_column :todos, :board_position, :integer

    execute <<~SQL
      UPDATE todos SET board_position = ranked.row
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY status ORDER BY due_on IS NULL, due_on, position, id) AS row
        FROM todos
      ) AS ranked
      WHERE todos.id = ranked.id
    SQL

    change_column_null :todos, :board_position, false
    add_index :todos, [ :status, :board_position ]
  end

  def down
    remove_index :todos, [ :status, :board_position ]
    remove_column :todos, :board_position
  end
end
