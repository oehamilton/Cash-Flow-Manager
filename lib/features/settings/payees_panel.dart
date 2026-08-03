import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../data/payee.dart';
import '../../data/payee_repository.dart';
import '../../theme/app_colors.dart';

/// Manage non-account payees (Phase 6.2).
class PayeesPanel extends StatefulWidget {
  const PayeesPanel({super.key, required this.auth});

  final AuthService? auth;

  @override
  State<PayeesPanel> createState() => _PayeesPanelState();
}

class _PayeesPanelState extends State<PayeesPanel> {
  String? _error;
  String? _mergeSourceId;

  PayeeRepository? get _repo {
    final session = widget.auth?.session;
    if (session == null) {
      return null;
    }
    return PayeeRepository(session);
  }

  Future<void> _addOrEdit({Payee? existing}) async {
    final repo = _repo;
    if (repo == null) {
      return;
    }
    final result = await showDialog<_PayeeFormResult>(
      context: context,
      builder: (context) => _PayeeEditorDialog(initial: existing),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      if (existing == null) {
        repo.create(
          PayeeDraft(
            name: result.name,
            notes: result.notes,
            url: result.url,
            phone: result.phone,
          ),
        );
      } else {
        repo.update(
          existing.id,
          PayeeUpdate(
            name: result.name,
            notes: result.notes,
            clearNotes: result.notes == null || result.notes!.trim().isEmpty,
            url: result.url,
            clearUrl: result.url == null || result.url!.trim().isEmpty,
            phone: result.phone,
            clearPhone: result.phone == null || result.phone!.trim().isEmpty,
          ),
        );
      }
      setState(() => _error = null);
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _delete(Payee payee) async {
    final repo = _repo;
    if (repo == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete payee?'),
        content: Text(
          'Remove "${payee.name}" from the directory? '
          'Transactions keep the payee text.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('payee_confirm_delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      repo.delete(payee.id);
      setState(() {
        _error = null;
        if (_mergeSourceId == payee.id) {
          _mergeSourceId = null;
        }
      });
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _mergeInto(Payee target) async {
    final repo = _repo;
    final sourceId = _mergeSourceId;
    if (repo == null || sourceId == null || sourceId == target.id) {
      return;
    }
    final source = repo.getById(sourceId);
    if (source == null) {
      setState(() => _mergeSourceId = null);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Merge payees?'),
        content: Text(
          'Merge "${source.name}" into "${target.name}"? '
          'Transactions move to "${target.name}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('payee_confirm_merge'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      repo.merge(sourceId: sourceId, targetId: target.id);
      setState(() {
        _mergeSourceId = null;
        _error = null;
      });
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final repo = _repo;
    final payees = repo?.listAll() ?? const <Payee>[];

    if (repo == null) {
      return Text(
        'Unlock a vault to manage payees.',
        style: textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: const Key('payee_add_button'),
          onPressed: () => _addOrEdit(),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Add payee'),
        ),
        if (_mergeSourceId != null) ...[
          const SizedBox(height: 8),
          Text(
            key: const Key('payee_merge_hint'),
            'Select another payee to merge into, or cancel.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.primaryBright,
            ),
          ),
          TextButton(
            key: const Key('payee_merge_cancel'),
            onPressed: () => setState(() => _mergeSourceId = null),
            child: const Text('Cancel merge'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: 12),
        if (payees.isEmpty)
          Text(
            key: const Key('payee_empty'),
            'No managed payees yet.',
            style: textTheme.bodyMedium,
          )
        else
          ...payees.map((payee) {
            final merging = _mergeSourceId == payee.id;
            return ListTile(
              key: Key('payee_row_${payee.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(payee.name),
              subtitle: payee.notes == null || payee.notes!.isEmpty
                  ? null
                  : Text(payee.notes!),
              selected: merging,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_mergeSourceId == null)
                    IconButton(
                      key: Key('payee_merge_${payee.id}'),
                      tooltip: 'Merge into another…',
                      onPressed: () =>
                          setState(() => _mergeSourceId = payee.id),
                      icon: const Icon(Icons.merge_type, size: 20),
                    )
                  else if (!merging)
                    IconButton(
                      key: Key('payee_merge_target_${payee.id}'),
                      tooltip: 'Merge into this payee',
                      onPressed: () => _mergeInto(payee),
                      icon: const Icon(Icons.input, size: 20),
                    ),
                  IconButton(
                    key: Key('payee_edit_${payee.id}'),
                    tooltip: 'Edit',
                    onPressed: () => _addOrEdit(existing: payee),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    key: Key('payee_delete_${payee.id}'),
                    tooltip: 'Delete',
                    onPressed: () => _delete(payee),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _PayeeFormResult {
  const _PayeeFormResult({
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

class _PayeeEditorDialog extends StatefulWidget {
  const _PayeeEditorDialog({this.initial});

  final Payee? initial;

  @override
  State<_PayeeEditorDialog> createState() => _PayeeEditorDialogState();
}

class _PayeeEditorDialogState extends State<_PayeeEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final TextEditingController _url;
  late final TextEditingController _phone;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _notes = TextEditingController(text: initial?.notes ?? '');
    _url = TextEditingController(text: initial?.url ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _url.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    Navigator.of(context).pop(
      _PayeeFormResult(
        name: name,
        notes: _notes.text,
        url: _url.text,
        phone: _phone.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AlertDialog(
      key: const Key('payee_editor_dialog'),
      backgroundColor: AppColors.surface,
      title: Text(isEdit ? 'Edit payee' : 'Add payee'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('payee_name_field'),
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('payee_notes_field'),
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('payee_url_field'),
              controller: _url,
              decoration: const InputDecoration(labelText: 'Website'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('payee_phone_field'),
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('payee_save_button'),
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
