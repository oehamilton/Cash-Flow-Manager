/// Current on-disk schema version for Cash Flow Manager databases.
const int kSchemaVersion = 1;

/// DDL applied when creating or migrating to [kSchemaVersion].
abstract final class SchemaV1 {
  static const List<String> createStatements = [
    '''
CREATE TABLE schema_version (
  version INTEGER NOT NULL
)
''',
    '''
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
)
''',
    '''
CREATE TABLE accounts (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  institution TEXT,
  account_number TEXT,
  login_url TEXT,
  login_username TEXT,
  login_password TEXT,
  contact_name TEXT,
  contact_phone TEXT,
  contact_email TEXT,
  notes TEXT,
  interest_rate_apr REAL,
  minimum_payment_cents INTEGER,
  payment_due_day INTEGER,
  currency_code TEXT NOT NULL DEFAULT 'USD',
  is_primary INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  include_in_debt_list INTEGER NOT NULL DEFAULT 0,
  opening_balance_cents INTEGER NOT NULL DEFAULT 0,
  opening_date TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''',
    '''
CREATE TABLE recurrence_rules (
  id TEXT PRIMARY KEY NOT NULL,
  account_id TEXT NOT NULL REFERENCES accounts(id),
  linked_account_id TEXT REFERENCES accounts(id),
  payee TEXT NOT NULL,
  memo TEXT,
  amount_cents INTEGER NOT NULL,
  frequency TEXT NOT NULL,
  interval INTEGER NOT NULL DEFAULT 1,
  anchor_date TEXT NOT NULL,
  next_scheduled_date TEXT,
  end_date TEXT,
  auto_clear INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''',
    '''
CREATE TABLE transactions (
  id TEXT PRIMARY KEY NOT NULL,
  account_id TEXT NOT NULL REFERENCES accounts(id),
  date TEXT NOT NULL,
  post_date TEXT,
  payee TEXT,
  memo TEXT,
  amount_cents INTEGER NOT NULL,
  is_cleared INTEGER NOT NULL DEFAULT 0,
  cleared_at TEXT,
  source TEXT NOT NULL,
  recurrence_rule_id TEXT REFERENCES recurrence_rules(id),
  recurrence_instance_key TEXT,
  is_user_overridden INTEGER NOT NULL DEFAULT 0,
  transfer_pair_id TEXT,
  interest_cents INTEGER,
  principal_cents INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(account_id, recurrence_instance_key)
)
''',
    '''
CREATE INDEX idx_transactions_account_date
  ON transactions(account_id, date, id)
''',
    '''
CREATE INDEX idx_transactions_account_cleared
  ON transactions(account_id, is_cleared)
''',
    '''
CREATE INDEX idx_transactions_recurrence
  ON transactions(recurrence_rule_id)
''',
  ];
}
