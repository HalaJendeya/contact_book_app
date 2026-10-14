import 'package:flutter/material.dart';

import '../models/contact.dart';

// One form used for both "add" and "edit".
//  - Add:  initialContact is null, so the fields start empty.
//  - Edit: initialContact is given, so the fields are pre-filled.
//
// The form does NOT call the API. It only collects the three values and
// hands them to [onSubmit]. [onSubmit] returns true when saving worked.
class ContactForm extends StatefulWidget {
  const ContactForm({super.key, this.initialContact, required this.onSubmit});

  final Contact? initialContact;
  final Future<bool> Function(String name, String email, String phone)
      onSubmit;

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _isSaving = false; // true while the request is running
  bool _saveFailed = false; // true after a failed save

  @override
  void initState() {
    super.initState();
    final contact = widget.initialContact;
    _nameController = TextEditingController(text: contact?.name ?? '');
    _emailController = TextEditingController(text: contact?.email ?? '');
    _phoneController = TextEditingController(text: contact?.phone ?? '');
  }

  @override
  void dispose() {
    // Controllers must be disposed to free their memory.
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving) return; // ignore a second tap while saving
    if (!_formKey.currentState!.validate()) return; // some field is empty

    setState(() {
      _isSaving = true;
      _saveFailed = false;
    });

    final success = await widget.onSubmit(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
    );

    // The dialog may have been closed while we were waiting.
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(); // close the dialog
    } else {
      setState(() {
        _isSaving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            enabled: !_isSaving,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'الاسم',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            enabled: !_isSaving,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'البريد الإلكتروني',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            enabled: !_isSaving,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            validator: _required,
          ),
          if (_saveFailed) ...[
            const SizedBox(height: 12),
            Text(
              'تعذر الحفظ، حاول مرة أخرى.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 8),
              // onPressed is null while saving, so the button is disabled.
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
