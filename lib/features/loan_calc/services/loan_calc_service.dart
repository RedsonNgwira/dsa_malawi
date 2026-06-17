import 'dart:math';

/// Result of a loan calculation.
class LoanCalcResult {
  final double loanAmount, adminFee, totalLoan, annualRate;
  final double monthlyInstalment, monthlyInsurance, totalMonthly;
  final double existingDebt, netPay, totalRepayable;
  final List<AmortRow> amortization;

  const LoanCalcResult({
    required this.loanAmount, required this.adminFee, required this.totalLoan,
    required this.annualRate, required this.monthlyInstalment,
    required this.monthlyInsurance, required this.totalMonthly,
    required this.existingDebt, required this.netPay, required this.totalRepayable,
    required this.amortization,
  });
}

class AmortRow {
  final int month;
  final double payment, principal, interest, balance;
  const AmortRow(this.month, this.payment, this.principal, this.interest, this.balance);
}

/// Pure loan calculation logic — no UI.
class LoanCalcService {
  static double annualRate(Map<String, dynamic> rates, int term, bool platinum) {
    if (platinum && term == 60) return (rates['platinum_60'] ?? 0.38) as double;
    if (term <= 36) return (rates['term_12_36'] ?? 0.475) as double;
    if (term >= 42 && term <= 52) return (rates['term_42_52'] ?? 0.465) as double;
    return (rates['term_60'] ?? 0.425) as double;
  }

  static double adminFeeRate(Map<String, dynamic> fees, bool platinum) {
    return platinum
        ? (fees['admin_fee_platinum'] ?? 0.07) as double
        : (fees['admin_fee_standard'] ?? 0.025) as double;
  }

  static double monthlyInsurance(Map<String, dynamic> fees) {
    return (fees['monthly_insurance'] ?? 0.00125) as double;
  }

  static const termOptions = [12, 24, 36, 42, 48, 52, 60];

  static LoanCalcResult? calculate({
    required double amount,
    required int termMonths,
    required bool platinum,
    double existingDebt = 0,
    required Map<String, dynamic> interestRates,
    required Map<String, dynamic> feeRates,
  }) {
    if (amount <= 0) return null;
    final adminFee = adminFeeRate(feeRates, platinum) * (termMonths / 12) * amount;
    final totalLoan = amount + adminFee;
    final annualRateVal = annualRate(interestRates, termMonths, platinum);
    final monthlyRate = annualRateVal / 12;
    final insuranceRate = monthlyInsurance(feeRates);
    final monthlyInstalment = monthlyRate * totalLoan / (1 - pow(1 + monthlyRate, -termMonths));
    final monthlyInsuranceAmt = insuranceRate * totalLoan;
    final totalMonthly = monthlyInstalment + monthlyInsuranceAmt;
    final netPay = totalLoan - existingDebt - adminFee;
    final totalRepayable = totalMonthly * termMonths;

    final rows = <AmortRow>[];
    var balance = totalLoan;
    for (var m = 1; m <= termMonths; m++) {
      final interest = balance * monthlyRate;
      final principal = monthlyInstalment - interest;
      balance -= principal;
      rows.add(AmortRow(m, monthlyInstalment, principal, interest, balance < 0 ? 0 : balance));
    }
    return LoanCalcResult(
      loanAmount: amount, adminFee: adminFee, totalLoan: totalLoan,
      annualRate: annualRateVal, monthlyInstalment: monthlyInstalment,
      monthlyInsurance: monthlyInsuranceAmt, totalMonthly: totalMonthly,
      existingDebt: existingDebt, netPay: netPay, totalRepayable: totalRepayable,
      amortization: rows,
    );
  }
}
