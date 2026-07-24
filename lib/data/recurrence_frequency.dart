/// Stored values for [recurrence_rules.frequency].
enum RecurrenceFrequency {
  daily,
  weekly,
  biweekly,
  semimonthly,
  monthly,
  quarterly,
  yearly;

  String get dbValue => name;

  String get label => switch (this) {
        RecurrenceFrequency.daily => 'Daily',
        RecurrenceFrequency.weekly => 'Weekly',
        RecurrenceFrequency.biweekly => 'Every 2 weeks',
        RecurrenceFrequency.semimonthly => 'Twice a month',
        RecurrenceFrequency.monthly => 'Monthly',
        RecurrenceFrequency.quarterly => 'Quarterly',
        RecurrenceFrequency.yearly => 'Yearly',
      };

  static RecurrenceFrequency parse(String value) {
    return RecurrenceFrequency.values.firstWhere(
      (f) => f.dbValue == value,
      orElse: () => throw FormatException('Unknown frequency: $value'),
    );
  }
}
