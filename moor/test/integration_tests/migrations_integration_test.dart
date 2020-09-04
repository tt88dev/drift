@TestOn('vm')
import 'package:moor/ffi.dart';
import 'package:moor/moor.dart';
import 'package:test/test.dart';

import '../data/tables/todos.dart';

void main() {
  test('change column types', () async {
    // Create todos table with category as text (it's an int? in Dart).
    final executor = VmDatabase.memory(setup: (db) {
      db.execute('''
        CREATE TABLE todos (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          target_date INTEGER NOT NULL,
          category TEXT NOT NULL
        );
      ''');

      db.execute('INSERT INTO todos (title, content, target_date, category) '
          "VALUES ('title', 'content', 0, '12')");
    });

    final db = TodoDb(executor);
    db.migration = MigrationStrategy(
      onCreate: (m) async {
        await m.alterTable(
          TableMigration(
            db.todosTable,
            columnTransformer: {
              db.todosTable.category:
                  const CustomExpression('CAST(category AS INT)'),
            },
          ),
        );
      },
    );

    final createStmt = await db
        .customSelect("SELECT sql FROM sqlite_schema WHERE name = 'todos'")
        .map((row) => row.readString('sql'))
        .getSingle();

    expect(createStmt, contains('category INT'));

    final item = await db.select(db.todosTable).getSingle();
    expect(item.category, 12);
  });
}
