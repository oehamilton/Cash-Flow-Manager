/// Managed non-account payee (Phase 6.2).
class Payee {
  const Payee({
    required this.id,
    required this.name,
    this.notes,
    this.url,
    this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? notes;
  final String? url;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Payee.fromRow(Map<String, Object?> row) {
    return Payee(
      id: row['id'] as String,
      name: row['name'] as String,
      notes: row['notes'] as String?,
      url: row['url'] as String?,
      phone: row['phone'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}

class PayeeDraft {
  const PayeeDraft({
    required this.name,
    this.notes,
    this.url,
    this.phone,
  });

  final String name;
  final String? notes;
  final String? url;
  final String? phone;
}

class PayeeUpdate {
  const PayeeUpdate({
    this.name,
    this.notes,
    this.clearNotes = false,
    this.url,
    this.clearUrl = false,
    this.phone,
    this.clearPhone = false,
  });

  final String? name;
  final String? notes;
  final bool clearNotes;
  final String? url;
  final bool clearUrl;
  final String? phone;
  final bool clearPhone;
}
