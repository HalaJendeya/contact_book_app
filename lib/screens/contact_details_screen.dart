import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/contact.dart';

// Shows one contact in detail, with Call / Email / Edit / Delete buttons.
//
// This screen does NOT talk to the API and does NOT own the list.
// The list screen gives it:
//   - [contact]  the contact to show
//   - [onEdit]   opens the edit form; returns the updated Contact (or null)
//   - [onDelete] asks for confirmation and deletes; returns true if deleted
// So all the real work stays in one place (the list screen).
class ContactDetailsScreen extends StatefulWidget {
  const ContactDetailsScreen({
    super.key,
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  final Contact contact;
  final Future<Contact?> Function(Contact contact) onEdit;
  final Future<bool> Function(Contact contact) onDelete;

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  // Our own copy of the contact, so we can show the edited values right away.
  late Contact _contact = widget.contact;

  bool _isBusy = false; // true while a delete is in progress

  // Edit: the list screen opens the form. If the user saved, we get the
  // updated contact back and show it immediately.
  Future<void> _edit() async {
    final updated = await widget.onEdit(_contact);
    if (updated != null && mounted) {
      setState(() => _contact = updated);
    }
  }

  // Delete: the list screen shows the confirmation and sends DELETE.
  // We only leave this screen if the contact was really deleted.
  Future<void> _delete() async {
    if (_isBusy) return; // ignore a second tap
    setState(() => _isBusy = true);

    final deleted = await widget.onDelete(_contact);
    if (!mounted) return;

    if (deleted) {
      Navigator.of(context).pop(); // back to the list
    } else {
      setState(() => _isBusy = false); // cancelled or failed: stay here
    }
  }

  // Opens the phone app or the email app.
  Future<void> _launch(Uri uri) async {
    bool opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (e) {
      opened = false;
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('تعذر فتح التطبيق المناسب على هذا الجهاز'),
            backgroundColor: Colors.red.shade700,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل جهة الاتصال')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          // Scrollable, so a long name or a small screen never overflows.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Large avatar with the first letter.
                Center(
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      _contact.firstLetter,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // No maxLines here: a long name simply wraps to more lines.
                Text(
                  _contact.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Call and Email buttons.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _launch(
                        Uri(scheme: 'tel', path: _contact.phone),
                      ),
                      icon: const Icon(Icons.call),
                      label: const Text('اتصال'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _launch(
                        Uri(scheme: 'mailto', path: _contact.email),
                      ),
                      icon: const Icon(Icons.email),
                      label: const Text('بريد إلكتروني'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Information card.
                Card(
                  margin: EdgeInsets.zero,
                  color: Colors.white,
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.email_outlined,
                        label: 'البريد الإلكتروني',
                        value: _contact.email,
                      ),
                      const Divider(height: 1),
                      _InfoTile(
                        icon: Icons.phone_outlined,
                        label: 'رقم الهاتف',
                        value: _contact.phone,
                      ),
                      const Divider(height: 1),
                      _InfoTile(
                        icon: Icons.tag,
                        label: 'المعرّف',
                        value: '${_contact.id}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Edit and Delete buttons.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _edit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تعديل'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// One row of the information card: icon + small label + the value.
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      // The value wraps onto several lines if it is long.
      // Emails and phone numbers are always left-to-right.
      subtitle: Text(
        value,
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }
}
