import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class LoanCalcScreen extends StatefulWidget {
  const LoanCalcScreen({super.key});

  @override
  State<LoanCalcScreen> createState() => _LoanCalcScreenState();
}

class _LoanCalcScreenState extends State<LoanCalcScreen> {
  final _amountCtrl = TextEditingController(text: '1000000');
  final _debtCtrl = TextEditingController(text: '0');
  int _termMonths = 12;
  bool _platinum = false;

  // Term options from Excel
  static const _termOptions = [12, 24, 36, 42, 48, 52, 60];

  // --- Excel constants ---
  static const _adminFeeStd = 0.025;      // 2.5%
  static const _adminFeePlatinum = 0.07;  // 7%
  static const _monthlyInsurance = 0.00125; // 0.125%

  double _annualRate(int term, bool platinum) {
    if (platinum && term == 60) return 0.38;
    if (term <= 36) return 0.475;
    if (term >= 42 && term <= 52) return 0.465;
    return 0.425; // 60+
  }

  double _adminFeeRate(bool platinum) =>
      platinum ? _adminFeePlatinum : _adminFeeStd;

  _LoanResult? _calc() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    final existingDebt = double.tryParse(_debtCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount == null || amount <= 0) return null;

    final adminFee = _adminFeeRate(_platinum) * ((_termMonths / 12)) * amount;
    final totalLoan = amount + adminFee;
    final annualRate = _annualRate(_termMonths, _platinum);
    final monthlyRate = annualRate / 12;

    // PMT formula: rate * PV / (1 - (1+rate)^-n)
    final monthlyInstalment = monthlyRate * totalLoan / (1 - pow(1 + monthlyRate, -_termMonths));
    final monthlyInsuranceAmt = _monthlyInsurance * totalLoan;
    final totalMonthly = monthlyInstalment + monthlyInsuranceAmt;
    final netPay = totalLoan - existingDebt - adminFee;
    final totalRepayable = totalMonthly * _termMonths;

    // Amortization table
    final rows = <AmortRow>[];
    var balance = totalLoan;
    for (var m = 1; m <= _termMonths; m++) {
      final interest = balance * monthlyRate;
      final principal = monthlyInstalment - interest;
      balance -= principal;
      rows.add(AmortRow(m, monthlyInstalment, principal, interest, balance < 0 ? 0 : balance));
    }

    return _LoanResult(
      loanAmount: amount,
      adminFee: adminFee,
      totalLoan: totalLoan,
      annualRate: annualRate,
      monthlyInstalment: monthlyInstalment,
      monthlyInsurance: monthlyInsuranceAmt,
      totalMonthly: totalMonthly,
      existingDebt: existingDebt,
      netPay: netPay,
      totalRepayable: totalRepayable,
      amortization: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _calc();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Inputs ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Loan Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _MWKField(label: 'Loan Amount (MWK)', controller: _amountCtrl, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 12),
                  // Term selector
                  Text('Loan Term', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _termOptions.map((t) => ChoiceChip(
                      label: Text('${t}m'),
                      selected: _termMonths == t,
                      onSelected: (_) => setState(() => _termMonths = t),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  _MWKField(label: 'Existing Debt to Settle (MWK)', controller: _debtCtrl, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Platinum Tier'),
                    subtitle: const Text('Lower rate (38%) + 7% admin fee'),
                    value: _platinum,
                    onChanged: (v) => setState(() => _platinum = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),

          if (result != null) ...[
            const SizedBox(height: 12),
            // --- Results ---
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ResultRow('Annual Interest Rate', '${(result.annualRate * 100).toStringAsFixed(1)}%', bold: true),
                    _ResultRow('Admin Fee', _mwk(result.adminFee)),
                    _ResultRow('Total Loan (incl. fee)', _mwk(result.totalLoan)),
                    const Divider(),
                    _ResultRow('Monthly Instalment', _mwk(result.monthlyInstalment)),
                    _ResultRow('Monthly Insurance (0.125%)', _mwk(result.monthlyInsurance)),
                    _ResultRow('Total Monthly Payment', _mwk(result.totalMonthly), bold: true, highlight: true),
                    const Divider(),
                    _ResultRow('Net Pay to Customer', _mwk(result.netPay), bold: true),
                    _ResultRow('Total Repayable', _mwk(result.totalRepayable)),
                    _ResultRow('Cost of Credit', _mwk(result.totalRepayable - result.loanAmount)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            // --- Amortization toggle ---
            _AmortizationTable(rows: result.amortization),
          ],
        ],
      ),
    );
  }

  String _mwk(double v) => 'MWK ${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
}

// ---- Sub-widgets ----

class _MWKField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _MWKField({required this.label, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,]'))],
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'MWK ',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool highlight;

  const _ResultRow(this.label, this.value, {this.bold = false, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 15 : 13,
      color: highlight ? Theme.of(context).colorScheme.primary : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _AmortizationTable extends StatefulWidget {
  final List<AmortRow> rows;
  const _AmortizationTable({required this.rows});

  @override
  State<_AmortizationTable> createState() => _AmortizationTableState();
}

class _AmortizationTableState extends State<_AmortizationTable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Amortization Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 0),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 36,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 32,
                columns: const [
                  DataColumn(label: Text('Mo', style: TextStyle(fontSize: 12))),
                  DataColumn(label: Text('Instalment', style: TextStyle(fontSize: 12))),
                  DataColumn(label: Text('Principal', style: TextStyle(fontSize: 12))),
                  DataColumn(label: Text('Interest', style: TextStyle(fontSize: 12))),
                  DataColumn(label: Text('Balance', style: TextStyle(fontSize: 12))),
                ],
                rows: widget.rows.map((r) => DataRow(cells: [
                  DataCell(Text('${r.month}', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(_fmt(r.instalment), style: const TextStyle(fontSize: 11))),
                  DataCell(Text(_fmt(r.principal), style: const TextStyle(fontSize: 11))),
                  DataCell(Text(_fmt(r.interest), style: const TextStyle(fontSize: 11))),
                  DataCell(Text(_fmt(r.balance), style: const TextStyle(fontSize: 11))),
                ])).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

// ---- Data models ----

class _LoanResult {
  final double loanAmount, adminFee, totalLoan, annualRate;
  final double monthlyInstalment, monthlyInsurance, totalMonthly;
  final double existingDebt, netPay, totalRepayable;
  final List<AmortRow> amortization;

  _LoanResult({
    required this.loanAmount, required this.adminFee, required this.totalLoan,
    required this.annualRate, required this.monthlyInstalment,
    required this.monthlyInsurance, required this.totalMonthly,
    required this.existingDebt, required this.netPay, required this.totalRepayable,
    required this.amortization,
  });
}

class AmortRow {
  final int month;
  final double instalment, principal, interest, balance;
  AmortRow(this.month, this.instalment, this.principal, this.interest, this.balance);
}
