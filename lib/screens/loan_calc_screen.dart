import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class LoanCalcScreen extends StatefulWidget {
  const LoanCalcScreen({super.key});

  @override
  State<LoanCalcScreen> createState() => _LoanCalcScreenState();
}

class _LoanCalcScreenState extends State<LoanCalcScreen> {
  final _amountCtrl = TextEditingController(text: '1000000');
  final _debtCtrl = TextEditingController(text: '0');
  final _labelCtrl = TextEditingController();
  int _termMonths = 12;
  bool _platinum = false;
  _SavedLoan? _selectedSaved;

  // Term options from Excel
  static const _termOptions = [12, 24, 36, 42, 48, 52, 60];

  double _annualRate(AppState state, int term, bool platinum) {
    if (platinum && term == 60) {
      return (state.interestRates['platinum_60'] ?? 0.38) as double;
    }
    if (term <= 36) return (state.interestRates['term_12_36'] ?? 0.475) as double;
    if (term >= 42 && term <= 52) return (state.interestRates['term_42_52'] ?? 0.465) as double;
    return (state.interestRates['term_60'] ?? 0.425) as double;
  }

  double _adminFeeRate(AppState state, bool platinum) {
    if (platinum) {
      return (state.feeRates['admin_fee_platinum'] ?? 0.07) as double;
    }
    return (state.feeRates['admin_fee_standard'] ?? 0.025) as double;
  }

  double _monthlyInsurance(AppState state) {
    return (state.feeRates['monthly_insurance'] ?? 0.00125) as double;
  }

  _LoanResult? _calc(AppState state) {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    final existingDebt = double.tryParse(_debtCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount == null || amount <= 0) return null;

    final adminFee = _adminFeeRate(state, _platinum) * ((_termMonths / 12)) * amount;
    final totalLoan = amount + adminFee;
    final annualRate = _annualRate(state, _termMonths, _platinum);
    final monthlyRate = annualRate / 12;
    final insuranceRate = _monthlyInsurance(state);

    // PMT formula: rate * PV / (1 - (1+rate)^-n)
    final monthlyInstalment = monthlyRate * totalLoan / (1 - pow(1 + monthlyRate, -_termMonths));
    final monthlyInsuranceAmt = insuranceRate * totalLoan;
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

  Future<void> _saveCalculation(AppState state, _LoanResult result) async {
    final label = _labelCtrl.text.trim();
    await state.addSavedLoan({
      'label': label.isNotEmpty ? label : 'Loan MWK ${_fmt(result.loanAmount)}',
      'loan_amount': result.loanAmount,
      'term_months': _termMonths,
      'platinum': _platinum ? 1 : 0,
      'existing_debt': result.existingDebt,
      'annual_rate': result.annualRate,
      'admin_fee': result.adminFee,
      'monthly_instalment': result.monthlyInstalment,
      'total_repayable': result.totalRepayable,
      'net_pay': result.netPay,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculation saved!')),
      );
    }
  }

  void _loadSaved(Map<String, dynamic> loan) {
    _amountCtrl.text = _fmt(loan['loan_amount'] as double);
    _debtCtrl.text = _fmt((loan['existing_debt'] ?? 0) as double);
    setState(() {
      _termMonths = loan['term_months'] as int;
      _platinum = (loan['platinum'] ?? 0) == 1;
      _selectedSaved = _SavedLoan(
        id: loan['id'] as int,
        label: loan['label'] as String? ?? '',
      );
    });
  }

  void _showSettings(AppState state) {
    final ratesCtrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(state.interestRates),
    );
    final feesCtrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(state.feeRates),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rate Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Interest Rates (annual)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: ratesCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Fee Rates', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: feesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Format: {"key": value}\nValues as decimals (e.g. 0.475 = 47.5%)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            try {
              final newRates = Map<String, dynamic>.from(jsonDecode(ratesCtrl.text));
              final newFees = Map<String, dynamic>.from(jsonDecode(feesCtrl.text));
              state.updateInterestRates(newRates);
              state.updateFeeRates(newFees);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rates updated')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invalid JSON: $e')),
              );
            }
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final result = _calc(state);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configure rates',
            onPressed: () => _showSettings(state),
          ),
          if (state.savedLoans.isNotEmpty)
            PopupMenuButton<_SavedLoan>(
              icon: const Icon(Icons.history),
              tooltip: 'Saved calculations',
              onSelected: (saved) {
                final loan = state.savedLoans.firstWhere(
                  (l) => l['id'] == saved.id,
                );
                _loadSaved(loan);
              },
              itemBuilder: (_) => state.savedLoans.map((loan) {
                final id = loan['id'] as int;
                final label = (loan['label'] as String?) ?? '';
                return PopupMenuItem<_SavedLoan>(
                  value: _SavedLoan(id: id, label: label),
                  child: Row(
                    children: [
                      Icon(Icons.calculate, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Inputs ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Loan Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_selectedSaved != null)
                        Chip(
                          label: Text(_selectedSaved!.label, style: const TextStyle(fontSize: 11)),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _selectedSaved = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MWKField(label: 'Loan Amount (MWK)', controller: _amountCtrl, onChanged: (_) => setState(() => _selectedSaved = null)),
                  const SizedBox(height: 12),
                  // Term selector
                  Text('Loan Term', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _termOptions.map((t) => ChoiceChip(
                      label: Text('${t}m'),
                      selected: _termMonths == t,
                      onSelected: (_) => setState(() {
                        _termMonths = t;
                        _selectedSaved = null;
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  _MWKField(label: 'Existing Debt to Settle (MWK)', controller: _debtCtrl, onChanged: (_) => setState(() => _selectedSaved = null)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Platinum Tier'),
                    subtitle: Text(
                      'Lower rate (${((state.interestRates['platinum_60'] ?? 0.38) as double) * 100}%) + ${((state.feeRates['admin_fee_platinum'] ?? 0.07) as double) * 100}% admin fee',
                    ),
                    value: _platinum,
                    onChanged: (v) => setState(() {
                      _platinum = v;
                      _selectedSaved = null;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),

          if (result != null) ...[
            const SizedBox(height: 12),
            // ── Results ──
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ResultRow(
                      'Annual Interest Rate',
                      '${(result.annualRate * 100).toStringAsFixed(1)}%',
                      bold: true,
                      tooltip: '≤36m: ${((state.interestRates['term_12_36'] ?? 0.475) as double) * 100}%\n'
                          '42–52m: ${((state.interestRates['term_42_52'] ?? 0.465) as double) * 100}%\n'
                          '60m: ${((state.interestRates['term_60'] ?? 0.425) as double) * 100}%\n'
                          'Platinum 60m: ${((state.interestRates['platinum_60'] ?? 0.38) as double) * 100}%',
                    ),
                    _ResultRow('Admin Fee (${(_adminFeeRate(state, _platinum) * 100).toStringAsFixed(1)}%)', _mwk(result.adminFee)),
                    _ResultRow('Total Loan (incl. fee)', _mwk(result.totalLoan)),
                    const Divider(),
                    _ResultRow('Monthly Instalment', _mwk(result.monthlyInstalment)),
                    _ResultRow('Monthly Insurance (${(_monthlyInsurance(state) * 100).toStringAsFixed(2)}%)', _mwk(result.monthlyInsurance)),
                    _ResultRow('Total Monthly Payment', _mwk(result.totalMonthly), bold: true, highlight: true),
                    const Divider(),
                    _ResultRow('Net Pay to Customer', _mwk(result.netPay), bold: true),
                    _ResultRow('Total Repayable', _mwk(result.totalRepayable)),
                    _ResultRow('Cost of Credit', _mwk(result.totalRepayable - result.loanAmount)),
                    const Divider(),
                    _ResultRow(
                      'Your Commission (est.)',
                      _mwk((result.loanAmount * ((state.feeRates['commission_rate'] ?? 0.01) as double))),
                      bold: true,
                      highlight: true,
                    ),
                    const SizedBox(height: 8),
                    // Save button
                    FilledButton.tonalIcon(
                      onPressed: () => _showSaveDialog(state, result),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save Calculation'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            // ── Amortization toggle ──
            _AmortizationTable(rows: result.amortization),
          ],
        ],
      ),
    );
  }

  void _showSaveDialog(AppState state, _LoanResult result) {
    _labelCtrl.text = 'Loan MWK ${_fmt(result.loanAmount)}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Calculation'),
        content: TextField(
          controller: _labelCtrl,
          decoration: const InputDecoration(
            labelText: 'Label',
            hintText: 'e.g. Client A - 12 months',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            Navigator.pop(ctx);
            _saveCalculation(state, result);
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  String _mwk(double v) => 'MWK ${_fmt(v)}';
  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

// ── Data models ──

class _SavedLoan {
  final int id;
  final String label;
  _SavedLoan({required this.id, required this.label});
}

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

// ── Sub-widgets ──

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
  final String? tooltip;

  const _ResultRow(this.label, this.value, {this.bold = false, this.highlight = false, this.tooltip});

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
          Row(
            children: [
              Text(label, style: style),
              if (tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip!,
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                ),
              ],
            ],
          ),
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
