import 'package:flutter/material.dart';

import 'calc.dart';

void main() => runApp(const CalculatorApp());

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Running Total Calculator',
    theme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      brightness: Brightness.dark,
    ),
    home: const CalculatorPage(),
  );
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final Calc calc = Calc();

  void _do(VoidCallback action) => setState(action);

  Widget _key(
    String label,
    VoidCallback onTap, {
    String? semantics,
    int flex = 1,
    bool accent = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Semantics(
          button: true,
          label: semantics ?? label,
          excludeSemantics: true,
          onTap: onTap,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              foregroundColor: accent ? scheme.onPrimary : scheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onTap,
            child: Text(label, style: const TextStyle(fontSize: 26)),
          ),
        ),
      ),
    );
  }

  Widget _row(List<Widget> keys) => Expanded(child: Row(children: keys));

  Widget _digit(String d) => _key(d, () => _do(() => calc.digit(d)));

  Widget _op(Op op, String name) => _key(
    opSymbols[op]!,
    () => _do(() => calc.operator(op)),
    semantics: name,
    accent: true,
  );

  @override
  Widget build(BuildContext context) {
    final pending = calc.pendingOp == null ? '' : opSymbols[calc.pendingOp]!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Semantics(
                  liveRegion: true,
                  label: 'Display ${calc.display}',
                  excludeSemantics: true,
                  child: Container(
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(pending, style: const TextStyle(fontSize: 24)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            calc.display,
                            style: TextStyle(
                              fontSize: 64,
                              color: calc.error != null
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _row([
                      _key(
                        'AC',
                        () => _do(calc.reset),
                        semantics: 'All clear',
                        flex: 2,
                      ),
                      _key(
                        '±',
                        () => _do(calc.toggleSign),
                        semantics: 'Toggle positive negative',
                      ),
                      _op(Op.div, 'divide'),
                    ]),
                    _row([
                      _digit('7'),
                      _digit('8'),
                      _digit('9'),
                      _op(Op.mul, 'multiply'),
                    ]),
                    _row([
                      _digit('4'),
                      _digit('5'),
                      _digit('6'),
                      _op(Op.sub, 'subtract'),
                    ]),
                    _row([
                      _digit('1'),
                      _digit('2'),
                      _digit('3'),
                      _op(Op.add, 'add'),
                    ]),
                    _row([
                      _key('0', () => _do(() => calc.digit('0')), flex: 2),
                      _key(
                        '.',
                        () => _do(calc.decimal),
                        semantics: 'decimal point',
                      ),
                      _key(
                        '=',
                        () => _do(calc.equals),
                        semantics: 'equals',
                        accent: true,
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
