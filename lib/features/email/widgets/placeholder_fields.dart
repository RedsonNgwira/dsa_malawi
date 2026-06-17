import 'package:flutter/material.dart';

/// Placeholder fields that appear when an email template is selected.
class PlaceholderFields extends StatelessWidget {
  final TextEditingController clientNameCtrl;
  final TextEditingController loanAmountCtrl;
  final VoidCallback onChanged;
  final VoidCallback onClose;

  const PlaceholderFields({
    super.key,
    required this.clientNameCtrl,
    required this.loanAmountCtrl,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.blue),
              const SizedBox(width: 6),
              const Text('Fill in template details',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 16, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: clientNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Client Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: loanAmountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Loan Amount (MWK)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
