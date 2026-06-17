import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/app_state.dart';
import '../features/loan_calc/services/loan_calc_service.dart';
import '../features/loan_calc/widgets/loan_result_card.dart';

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

  @override
  void dispose() {
    _amountCtrl.dispose();
    _debtCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) => FormatUtils.currency(v);

  void _showSettings(AppState state) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RateSettingsDialog(
        interestRates: Map<String, dynamic>.from(state.interestRates),
        feeRates: Map<String, dynamic>.from(state.feeRates),
      ),
    );
    if (result != null) {
      state.updateInterestRates(result['rates'] as Map<String, dynamic>);
      state.updateFeeRates(result['fees'] as Map<String, dynamic>);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rates updated')),
        );
      }
    }
  }

  void _save(AppState state, LoanCalcResult result) async {
    final label = _labelCtrl.text.trim();
    await state.addSavedLoan({
      'label': label.isNotEmpty ? label : 'Loan MWK ${_fmt(result.loanAmount)}',
      'loan_amount': result.loanAmount, 'term_months': _termMonths,
      'platinum': _platinum ? 1 : 0, 'existing_debt': result.existingDebt,
      'annual_rate': result.annualRate, 'admin_fee': result.adminFee,
      'monthly_instalment': result.monthlyInstalment,
      'total_repayable': result.totalRepayable, 'net_pay': result.netPay,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculation saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final result = LoanCalcService.calculate(
      amount: double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
      termMonths: _termMonths, platinum: _platinum,
      existingDebt: double.tryParse(_debtCtrl.text.replaceAll(',', '')) ?? 0,
      interestRates: state.interestRates, feeRates: state.feeRates,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Calculator', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.settings), tooltip: 'Rate Settings', onPressed: () => _showSettings(state)),
          IconButton(icon: const Icon(Icons.history), tooltip: 'Saved Calculations', onPressed: () => _showSaved(state)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(labelText: 'Loan Amount (MWK)', border: OutlineInputBorder(), prefixText: 'MWK '),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _termMonths, decoration: const InputDecoration(labelText: 'Term', border: OutlineInputBorder()),
                  items: LoanCalcService.termOptions.map((t) => DropdownMenuItem(value: t, child: Text('$t months'))).toList(),
                  onChanged: (v) => setState(() => _termMonths = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _debtCtrl,
                  decoration: const InputDecoration(labelText: 'Existing Debt', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Platinum Client'), value: _platinum,
            onChanged: (v) => setState(() => _platinum = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          TextField(controller: _labelCtrl, decoration: const InputDecoration(labelText: 'Label (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 16),

          if (result != null) ...[
            LoanResultCard(result: result, fmt: _fmt),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _save(state, result),
              icon: const Icon(Icons.save),
              label: const Text('Save Calculation'),
            ),
            const SizedBox(height: 24),
            AmortizationTable(rows: result.amortization),
          ],
        ],
      ),
    );
  }

  void _showSaved(AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Saved Calculations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              ),
            ),
            if (state.savedLoans.isEmpty)
              const Expanded(child: Center(child: Text('No saved calculations yet')))
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: state.savedLoans.length,
                  itemBuilder: (_, i) {
                    final loan = state.savedLoans[i];
                    final label = (loan['label'] as String?) ?? 'Loan';
                    final amt = (loan['loan_amount'] as double?) ?? 0;
                    final term = (loan['term_months'] as int?) ?? 0;
                    return ListTile(
                      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('MWK ${_fmt(amt)} · $term months'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => state.removeSavedLoan(loan['id'] as int),
                      ),
                      onTap: () { Navigator.pop(ctx); _loadSaved(loan); },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _loadSaved(Map<String, dynamic> loan) {
    _amountCtrl.text = _fmt((loan['loan_amount'] as double?) ?? 0);
    _debtCtrl.text = _fmt((loan['existing_debt'] as double?) ?? 0);
    setState(() {
      _termMonths = (loan['term_months'] as int?) ?? 12;
      _platinum = (loan['platinum'] ?? 0) == 1;
    });
  }
}
