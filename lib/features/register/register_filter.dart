import '../../data/transaction.dart';

/// Cleared-status facet for the register filter bar (Phase 2.6).
enum ClearedFilter {
  all,
  cleared,
  uncleared,
}

/// Light register filter: payee/memo text, cleared status, optional date bounds.
class RegisterFilter {
  const RegisterFilter({
    this.query = '',
    this.cleared = ClearedFilter.all,
    this.dateFrom,
    this.dateTo,
  });

  final String query;
  final ClearedFilter cleared;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  bool get isActive =>
      query.trim().isNotEmpty ||
      cleared != ClearedFilter.all ||
      dateFrom != null ||
      dateTo != null;

  RegisterFilter copyWith({
    String? query,
    ClearedFilter? cleared,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return RegisterFilter(
      query: query ?? this.query,
      cleared: cleared ?? this.cleared,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }
}

/// Filters register entries; keeps each row's original running balance.
List<RegisterEntry> applyRegisterFilter(
  Iterable<RegisterEntry> entries,
  RegisterFilter filter,
) {
  final q = filter.query.trim().toLowerCase();
  final from = filter.dateFrom == null
      ? null
      : DateTime(
          filter.dateFrom!.year,
          filter.dateFrom!.month,
          filter.dateFrom!.day,
        );
  final to = filter.dateTo == null
      ? null
      : DateTime(
          filter.dateTo!.year,
          filter.dateTo!.month,
          filter.dateTo!.day,
        );

  return [
    for (final entry in entries)
      if (_matches(entry.transaction, q, filter.cleared, from, to)) entry,
  ];
}

bool _matches(
  Transaction tx,
  String query,
  ClearedFilter cleared,
  DateTime? from,
  DateTime? to,
) {
  switch (cleared) {
    case ClearedFilter.cleared:
      if (!tx.isCleared) {
        return false;
      }
    case ClearedFilter.uncleared:
      if (tx.isCleared) {
        return false;
      }
    case ClearedFilter.all:
      break;
  }

  final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
  if (from != null && txDate.isBefore(from)) {
    return false;
  }
  if (to != null && txDate.isAfter(to)) {
    return false;
  }

  if (query.isEmpty) {
    return true;
  }
  final payee = (tx.payee ?? '').toLowerCase();
  final memo = (tx.memo ?? '').toLowerCase();
  return payee.contains(query) || memo.contains(query);
}
