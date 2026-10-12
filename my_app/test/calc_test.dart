import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/calc.dart';

/// Keys: digits, . + - * / = C (all clear) ~ (sign toggle)
Calc run(String keys) {
  final c = Calc();
  for (final k in keys.split('')) {
    switch (k) {
      case '+':
        c.operator(Op.add);
      case '-':
        c.operator(Op.sub);
      case '*':
        c.operator(Op.mul);
      case '/':
        c.operator(Op.div);
      case '=':
        c.equals();
      case 'C':
        c.reset();
      case '~':
        c.toggleSign();
      case '.':
        c.decimal();
      default:
        c.digit(k);
    }
  }
  return c;
}

void main() {
  group('core contract', () {
    test('2 + 3 shows 3', () => expect(run('2+3').display, '3'));
    test(
      '2 + 3 × shows running total 5',
      () => expect(run('2+3*').display, '5'),
    );
    test(
      '2 + 3 × 4 = is 20 (no precedence)',
      () => expect(run('2+3*4=').display, '20'),
    );
    test(
      '9 + × 2 = replaces operator -> 18',
      () => expect(run('9+*2=').display, '18'),
    );
    test('7 + = ignores equals, keeps pending op', () {
      final c = run('7+=');
      expect(c.display, '7');
      expect(c.pendingOp, Op.add);
    });
    test(
      'digit after equals starts fresh',
      () => expect(run('2+3=9').display, '9'),
    );
    test(
      'operator after equals continues from result',
      () => expect(run('2+3=*2=').display, '10'),
    );
    test('chained all four ops', () => expect(run('8/2-1*6=').display, '18'));
  });

  group('AC', () {
    test('clears everything', () {
      final c = run('2+3*C');
      expect(c.display, '0');
      expect(c.accumulator, isNull);
      expect(c.pendingOp, isNull);
      expect(run('2+3*C4=').display, '4'); // no stale accumulator or operator
    });
  });

  group('error handling', () {
    test(
      'divide by zero shows error',
      () => expect(run('5/0=').error, isNotNull),
    );
    test(
      'divide by zero mid-chain',
      () => expect(run('5/0+').error, isNotNull),
    );
    test('operators ignored during error, AC recovers', () {
      final c = run('5/0=+');
      expect(c.error, isNotNull);
      c.reset();
      expect(c.display, '0');
    });
    test(
      'digit after error starts fresh',
      () => expect(run('5/0=7').display, '7'),
    );
  });

  group('sign toggle', () {
    test('zero stays 0', () => expect(run('~').display, '0'));
    test('toggles back and forth', () {
      expect(run('5~').display, '-5');
      expect(run('5~~').display, '5');
    });
    test(
      'after operator starts negative operand',
      () => expect(run('5+~3=').display, '2'),
    );
  });
}
