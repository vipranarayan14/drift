import 'package:recase/recase.dart';
import 'package:sqlparser/sqlparser.dart';

import '../../driver/error.dart';
import '../../results/column.dart';
import '../../results/table.dart';
import '../intermediate_state.dart';
import '../resolver.dart';
import 'type_mapper.dart';

class DriftTableResolver extends LocalElementResolver<DiscoveredDriftTable> {
  DriftTableResolver(super.discovered, super.resolver, super.state);

  @override
  Future<DriftTable> resolve() async {
    Table table;

    try {
      final reader = SchemaFromCreateTable(
        driftExtensions: true,
        driftUseTextForDateTime:
            resolver.driver.options.storeDateTimeValuesAsText,
      );
      table = reader.read(discovered.createTable);
    } catch (e, s) {
      resolver.driver.backend.log
          .warning('Error reading table from internal statement', e, s);
      reportError(DriftAnalysisError.inDriftFile(
        discovered.createTable.tableNameToken ?? discovered.createTable,
        'The structure of this table could not be extracted, possibly due to a '
        'bug in drift_dev.',
      ));
      rethrow;
    }

    final columns = <DriftColumn>[];

    for (final column in table.resultColumns) {
      String? overriddenDartName;
      final type = column.type.sqlTypeToDrift(resolver.driver.options);

      for (final constraint in column.constraints) {
        if (constraint is DriftDartName) {
          overriddenDartName = constraint.dartName;
        } else if (constraint is ForeignKeyColumnConstraint) {
          final referencedTable = await resolver.resolveReference(
            discovered.ownId,
            constraint.clause.foreignTable.tableName,
          );
        }
      }

      columns.add(DriftColumn(
        sqlType: type,
        nullable: column.type.nullable != false,
        nameInSql: column.name,
        nameInDart: overriddenDartName ?? ReCase(column.name).camelCase,
      ));
    }

    return DriftTable(discovered.ownId, null, columns: columns);
  }
}
