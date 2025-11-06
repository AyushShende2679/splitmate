import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'parent_monitor_screen.dart';

class ParentCodeScreen extends StatefulWidget {
  final String? initialCode;
  const ParentCodeScreen({super.key, this.initialCode});

  @override
  State<ParentCodeScreen> createState() => _ParentCodeScreenState();
}

class _ParentCodeScreenState extends State<ParentCodeScreen> {
  final _controller = TextEditingController();
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _controller.text = widget.initialCode!;
    }
  }

  Future<void> _validateCode() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a code")),
      );
      return;
    }

    setState(() => _validating = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection("monitor_codes")
          .doc(code)
          .get();

      if (!doc.exists) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("❌ Invalid code")));
        return;
      }

      final data = doc.data() ?? {};
      final String? childUid = data['childUid'];
      if (childUid == null || childUid.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("❌ Invalid code data")));
        return;
      }

      
      if (data['expiresAt'] != null && data['expiresAt'] is Timestamp) {
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiresAt)) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("⏰ Code expired")));
          return;
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentMonitorScreen(childUid: childUid),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter Monitor Code")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: "Monitor Code"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _validating ? null : _validateCode,
              child: Text(_validating ? "Validating..." : "Validate"),
            ),
          ],
        ),
      ),
    );
  }
}