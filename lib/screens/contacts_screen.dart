import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contact_service.dart';
import '../widgets/contact_form.dart';

class ContactsScreen extends StatefulWidget {
  // [service] is optional: the app uses the real one, tests pass a fake.
  const ContactsScreen({super.key, this.service});

  final ContactService? service;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late final ContactService _service;

  // FutureBuilder watches this Future for the first GET request only.
  late Future<List<Contact>> _future;

  // The list shown on screen. We change THIS list after add / edit / delete,
  // because JSONPlaceholder does not really save our changes.
  List<Contact> _contacts = [];

  // The server only knows users 1-10. A contact we add gets a temporary
  // local id starting at 1000, so it can never clash with a server id.
  static const int _firstLocalId = 1000;
  int _nextLocalId = _firstLocalId;

  bool _isDeleting = false; // blocks a second delete while one is running

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ContactService();
    _future = _loadContacts();
  }

  // Fetch from the API and keep the result in our local list.
  // If getContacts() throws, FutureBuilder receives the error.
  Future<List<Contact>> _loadContacts() async {
    final contacts = await _service.getContacts();
    _contacts = contacts;
    return contacts;
  }

  void _retry() {
    setState(() {
      _future = _loadContacts();
    });
  }

  bool _isLocal(Contact contact) => contact.id >= _firstLocalId;

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isError ? Colors.red.shade700 : null,
        ),
      );
  }

  // ---------------------------------------------------------------- ADD (POST)
  Future<bool> _addContact(String name, String email, String phone) async {
    try {
      final newContact = Contact(id: _nextLocalId, name: name, email: email, phone: phone);
      // Throws if the server does not answer 201.
      await _service.addContact(newContact);

      if (!mounted) return false;
      setState(() {
        _nextLocalId++;
        _contacts.insert(0, newContact); // show it at the top of the list
      });
      _showMessage('تمت إضافة جهة الاتصال');
      return true;
    } catch (e) {
      if (mounted) _showMessage('تعذر إضافة جهة الاتصال', isError: true);
      return false;
    }
  }

  // ----------------------------------------------------------------- EDIT (PUT)
  Future<bool> _editContact(
    Contact old,
    String name,
    String email,
    String phone,
  ) async {
    try {
      final updated = Contact(id: old.id, name: name, email: email, phone: phone);

      // A contact added in this session does not exist on the server, and
      // JSONPlaceholder answers 500 for a PUT on an unknown id. So we only
      // send the PUT for real server contacts.
      if (!_isLocal(old)) {
        await _service.updateContact(updated); // throws if status is not 200
      }

      if (!mounted) return false;
      setState(() {
        final index = _contacts.indexWhere((c) => c.id == old.id);
        if (index != -1) _contacts[index] = updated;
      });
      _showMessage('تم تحديث جهة الاتصال');
      return true;
    } catch (e) {
      if (mounted) _showMessage('تعذر تحديث جهة الاتصال', isError: true);
      return false;
    }
  }

  // Opens the form in a dialog. contact == null means "add", otherwise "edit".
  void _showForm({Contact? contact}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    contact == null ? 'إضافة جهة اتصال' : 'تعديل جهة اتصال',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ContactForm(
                    initialContact: contact,
                    onSubmit: (name, email, phone) {
                      if (contact == null) {
                        return _addContact(name, email, phone);
                      }
                      return _editContact(contact, name, email, phone);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- DELETE (DELETE)
  // Dismissible calls this after the user swipes, BEFORE removing the item.
  //   return true  -> the item slides away (then onDismissed runs)
  //   return false -> the item slides back and stays in the list
  Future<bool> _confirmAndDelete(Contact contact) async {
    if (_isDeleting) return false;
    _isDeleting = true;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('حذف جهة الاتصال'),
          content: Text('هل تريد حذف "${contact.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      );

      if (confirmed != true) return false; // cancelled: keep the contact

      await _service.deleteContact(contact.id); // throws if status is not 200
      return true; // success: let the item be dismissed
    } catch (e) {
      if (mounted) _showMessage('تعذر حذف جهة الاتصال', isError: true);
      return false; // failed: keep the contact
    } finally {
      _isDeleting = false;
    }
  }

  // Runs only after confirmDismiss returned true, so the server already said OK.
  void _onDeleted(Contact contact) {
    setState(() {
      _contacts.removeWhere((c) => c.id == contact.id);
    });
    _showMessage('تم حذف جهة الاتصال');
  }

  // ------------------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دفتر جهات الاتصال')),
      body: FutureBuilder<List<Contact>>(
        future: _future,
        builder: (context, snapshot) {
          // 1) Still waiting for the server.
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2) The request failed.
          if (snapshot.hasError) {
            return _buildError();
          }
          // 3) Success, but nothing to show.
          if (_contacts.isEmpty) {
            return _buildEmpty();
          }
          // 4) Success: show the list.
          return _buildList();
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'إضافة جهة اتصال',
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'تعذر تحميل جهات الاتصال.\nتحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contacts_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد جهات اتصال بعد.', textAlign: TextAlign.center),
            SizedBox(height: 4),
            Text(
              'اضغط على زر + لإضافة جهة اتصال.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    // Center + maxWidth keeps the list readable on wide screens.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView.builder(
          // Extra bottom space so the floating button never hides the last card.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: _contacts.length,
          itemBuilder: (context, index) {
            final contact = _contacts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                // The key tells Flutter which item is which. Ids are unique.
                key: ValueKey(contact.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) => _confirmAndDelete(contact),
                onDismissed: (direction) => _onDeleted(contact),
                child: _buildContactCard(contact),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContactCard(Contact contact) {
    final firstLetter =
        contact.name.trim().isEmpty ? '?' : contact.name.trim().substring(0, 1);

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _showForm(contact: contact), // long press = edit
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(Icons.email_outlined, contact.email),
                    const SizedBox(height: 4),
                    _buildInfoRow(Icons.phone_outlined, contact.phone),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Emails and phone numbers are left-to-right even in an RTL app.
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.end, // for left-to-right text, "end" is the right side
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}
