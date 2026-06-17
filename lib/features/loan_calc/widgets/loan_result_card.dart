import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/loan_calc_service.dart';

/// Displays amortization table rows.
class AmortizationTable extends StatelessWidget {
  final List<AmortRow> rows;
  const AmortizationTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Amortization Schedule', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final r = rows[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(width: 30, child: Text('${r.month}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    Expanded(child: Text('MWK ${r.payment.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12))),
                    Expanded(child: Text('MWK ${r.principal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12))),
                    Expanded(child: Text('MWK ${r.interest.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12))),
                    Expanded(child: Text('MWK ${r.balance.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 30),
            const Expanded(child: Text('Payment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
            const Expanded(child: Text('Principal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
            const Expanded(child: Text('Interest', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
            const Expanded(child: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
          ],
        ),
      ],
    );
  }
}

/// Summary card showing loan calculation results.
class LoanResultCard extends StatelessWidget {
  final LoanCalcResult result;
  final String Function(double) fmt;

  const LoanResultCard({super.key, required this.result, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Loan Amount', 'MWK ${fmt(result.loanAmount)}', theme),
            _row('Term', '${result.amortization.length} months', theme),
            _row('Annual Rate', '${(result.annualRate * 100).toStringAsFixed(1)}%', theme),
            const Divider(),
            _row('Admin Fee', 'MWK ${fmt(result.adminFee)}', theme, bold: true),
            _row('Monthly Insurance', 'MWK ${fmt(result.monthlyInsurance)}', theme),
            _row('Monthly Instalment', 'MWK ${fmt(result.monthlyInstalment)}', theme, bold: true),
            _row('Total Monthly', 'MWK ${fmt(result.totalMonthly)}', theme, bold: true),
            const Divider(),
            _row('Net Pay to Client', 'MWK ${fmt(result.netPay)}', theme,
                bold: true, color: Colors.green.shade700),
            _row('Total Repayable', 'MWK ${fmt(result.totalRepayable)}', theme,
                bold: true, color: Colors.red.shade700),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, ThemeData theme, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w600 : FontWeight.w400, color: Colors.grey.shade600)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Dialog for editing interest rates and fee rates as JSON.
class RateSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> interestRates;
  final Map<String, dynamic> feeRates;

  const RateSettingsDialog({super.key, required this.interestRates, required this.feeRates});

  @override
  State<RateSettingsDialog> createState() => _RateSettingsDialogState();
}

class _RateSettingsDialogState extends State<RateSettingsDialog> {
  late TextEditingController _ratesCtrl;
  late TextEditingController _feesCtrl;

  @override
  void initState() {
    super.initState();
    _ratesCtrl = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(widget.interestRates));
    _feesCtrl = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(widget.feeRates));
  }

  @override
  void dispose() {
    _ratesCtrl.dispose();
    _feesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Settings'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Interest Rates', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(controller: _ratesCtrl, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 12),
          const Text('Fee Rates', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(controller: _feesCtrl, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 6),
          Text('Format: {"key": value}\nValues as decimals', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    try {
      final newRates = Map<String, dynamic>.from(const JsonDecoder().convert(_ratesCtrl.text));
      final newFees = Map<String, dynamic>.from(const JsonDecoder().convert(_feesCtrl.text));
      Navigator.pop(context, {'rates': newRates, 'fees': newFees});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid JSON: $e')));
    }
  }
}
