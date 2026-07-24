/// Values for [audit_log.category] / [audit_log.action] (Phase 0.7+).
abstract final class AuditCategory {
  static const access = 'access';
  static const account = 'account';
  static const transaction = 'transaction';
  static const settings = 'settings';
  static const system = 'system';
}

abstract final class AuditAction {
  static const createVault = 'create_vault';
  static const unlockPassword = 'unlock_password';
  static const unlockHello = 'unlock_hello';
  static const unlockFailed = 'unlock_failed';
  static const lock = 'lock';
  static const forceUnlock = 'force_unlock';
  static const helloEnable = 'hello_enable';
  static const helloDisable = 'hello_disable';
  static const create = 'create';
  static const update = 'update';
  static const delete = 'delete';
  static const archive = 'archive';
  static const clear = 'clear';
  static const unclear = 'unclear';
  static const reconcile = 'reconcile';
}

abstract final class AuditEntityType {
  static const vault = 'vault';
  static const account = 'account';
  static const transaction = 'transaction';
  static const recurrenceRule = 'recurrence_rule';
}
