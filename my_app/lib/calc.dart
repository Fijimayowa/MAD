enum Op { add, sub, mul, div }

const opSymbols = {Op.add: '+', Op.sub: '−', Op.mul: '×', Op.div: '÷'};

/// Left-to-right running-total calculator state (no operator precedence).
///
/// Authoritative state: accumulator, currentOperand, pendingOp,
/// awaitingOperand, justEvaluated, error.
/// Derived: [display] (never stored separately, so it cannot go stale).
///
/// Invariant: awaitingOperand == true  =>  accumulator != null && pendingOp != null.
class Calc {
  double? accumulator;
  String currentOperand = '0';
  Op? pendingOp;
  bool awaitingOperand = false;
  bool justEvaluated = false;
  String? error;

  String get display =>
      error ?? (awaitingOperand ? format(accumulator!) : currentOperand);

  // --- transitions -------------------------------------------------------

  void digit(String d) {
    if (error != null || justEvaluated) reset(); // fresh calculation
    if (awaitingOperand) {
      currentOperand = d;
      awaitingOperand = false;
    } else if (currentOperand == '0') {
      currentOperand = d;
    } else if (currentOperand == '-0') {
      currentOperand = '-$d';
    } else {
      currentOperand += d;
    }
  }

  void decimal() {
    if (error != null || justEvaluated) reset();
    if (awaitingOperand) {
      currentOperand = '0.';
      awaitingOperand = false;
    } else if (!currentOperand.contains('.')) {
      currentOperand += '.';
    }
  }

  void operator(Op op) {
    if (error != null) return;
    justEvaluated = false;
    if (pendingOp != null && awaitingOperand) {
      pendingOp = op; // operator pressed twice: replace
      return;
    }
    if (pendingOp != null) {
      final result = _apply(accumulator!, pendingOp!, _operandValue());
      if (result == null) return _fail();
      accumulator = result;
    } else {
      accumulator = _operandValue();
    }
    pendingOp = op;
    awaitingOperand = true;
  }

  void equals() {
    if (error != null || pendingOp == null || awaitingOperand) return; // ignore
    final result = _apply(accumulator!, pendingOp!, _operandValue());
    if (result == null) return _fail();
    currentOperand = format(result);
    accumulator = null;
    pendingOp = null;
    justEvaluated = true;
  }

  void toggleSign() {
    if (error != null) return;
    if (awaitingOperand) {
      currentOperand = '-0'; // start next operand as negative
      awaitingOperand = false;
      return;
    }
    if (currentOperand == '0') return; // zero has no sign
    currentOperand = currentOperand.startsWith('-')
        ? currentOperand.substring(1)
        : '-$currentOperand';
  }

  void reset() {
    accumulator = null;
    currentOperand = '0';
    pendingOp = null;
    awaitingOperand = false;
    justEvaluated = false;
    error = null;
  }

  // --- helpers -----------------------------------------------------------

  double _operandValue() => double.parse(
    currentOperand.endsWith('.')
        ? currentOperand.substring(0, currentOperand.length - 1)
        : currentOperand,
  );

  double? _apply(double a, Op op, double b) {
    switch (op) {
      case Op.add:
        return a + b;
      case Op.sub:
        return a - b;
      case Op.mul:
        return a * b;
      case Op.div:
        return b == 0 ? null : a / b;
    }
  }

  void _fail() {
    error = 'Cannot divide by 0';
    accumulator = null;
    pendingOp = null;
    awaitingOperand = false;
    justEvaluated = false;
  }

  static String format(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    var s = v.toStringAsPrecision(10);
    if (s.contains('e')) return s;
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }
}
