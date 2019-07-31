import 'package:sqlparser/src/utils/ast_equality.dart';
import 'package:test/test.dart';
import 'package:sqlparser/sqlparser.dart';

import '../parser/utils.dart';
import 'data.dart';

void main() {
  test('correctly resolves return columns', () {
    final engine = SqlEngine()..registerTable(demoTable);

    final context =
        engine.analyze('SELECT id, d.content, *, 3 + 4 FROM demo AS d');

    final select = context.root as SelectStatement;
    final resolvedColumns = select.resolvedColumns;

    expect(context.errors, isEmpty);

    expect(resolvedColumns.map((c) => c.name),
        ['id', 'content', 'id', 'content', '3 + 4']);

    expect(resolvedColumns.map((c) => context.typeOf(c).type.type), [
      BasicType.int,
      BasicType.text,
      BasicType.int,
      BasicType.text,
      BasicType.int,
    ]);

    final firstColumn = select.columns[0] as ExpressionResultColumn;
    final secondColumn = select.columns[1] as ExpressionResultColumn;
    final from = select.from[0] as TableReference;

    expect((firstColumn.expression as Reference).resolved, id);
    expect((secondColumn.expression as Reference).resolved, content);
    expect(from.resolved, demoTable);
  });

  test('resolves the column for order by clauses', () {
    final engine = SqlEngine()..registerTable(demoTable);

    final context = engine
        .analyze('SELECT d.content, 3 * d.id AS t FROM demo AS d ORDER BY t');

    expect(context.errors, isEmpty);

    final select = context.root as SelectStatement;
    final orderingTerm = select.orderBy.terms.single.expression as Reference;
    final resolved = orderingTerm.resolved as ExpressionColumn;

    enforceEqual(
      resolved.expression,
      BinaryExpression(
        NumericLiteral(3, token(TokenType.numberLiteral)),
        token(TokenType.star),
        Reference(tableName: 'd', columnName: 'id'),
      ),
    );
  });

  test('resolves sub-queries', () {
    final engine = SqlEngine()..registerTable(demoTable);

    final context = engine.analyze(
        'SELECT d.*, (SELECT id FROM demo WHERE id = d.id) FROM demo d;');

    expect(context.errors, isEmpty);
  });
}
