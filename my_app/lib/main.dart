import 'dart:async';

import 'package:flutter/material.dart';

void main() => runApp(const PetApp());

class PetApp extends StatelessWidget {
  const PetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Pet',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const PetScreen(),
    );
  }
}

class PetScreen extends StatefulWidget {
  // Intervals are constructor params so tests can shorten them.
  // Production values: 30 seconds and 3 minutes.
  const PetScreen({
    super.key,
    this.hungerInterval = const Duration(seconds: 30),
    this.winDuration = const Duration(minutes: 3),
  });

  final Duration hungerInterval;
  final Duration winDuration;

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  // ---- Game state ----
  String _petName = 'Pip';
  int _happiness = 50;
  int _hunger = 50;
  int _energy = 70;
  bool _gameOver = false;
  bool _hasWon = false;
  String _feedback = 'Choose an action to see which pet values change.';

  // ---- Timers and short-lived animation state ----
  Timer? _hungerTimer;
  Timer? _highMoodTimer;
  Timer? _bounceTimer;
  Timer? _reactionTimer;
  bool _bouncing = false;
  String? _reaction;

  final TextEditingController _nameController = TextEditingController(
    text: 'Pip',
  );

  // ---- Rules ----
  int _clampMeter(int value) => value.clamp(0, 100).toInt();

  bool get _finished => _gameOver || _hasWon;

  String get _moodLabel {
    if (_happiness > 70) return 'Happy';
    if (_happiness >= 30) return 'Neutral';
    return 'Unhappy';
  }

  Color get _moodColor {
    if (_happiness > 70) return Colors.green;
    if (_happiness >= 30) return Colors.yellow;
    return Colors.red;
  }

  double get _petScale => _happiness > 70
      ? 1.06
      : _happiness < 30
      ? 0.94
      : 1.0;

  // Derived, never stored, so it can't drift out of sync.
  String get _petMessage {
    if (_gameOver) return 'I need a rest.';
    if (_hasWon) return 'Best day ever!';
    if (_hunger > 80) return "I'm starving!";
    if (_happiness <= 30) return 'Play with me?';
    if (_energy < 20) return 'So sleepy...';
    return "Hi, I'm $_petName!";
  }

  @override
  void initState() {
    super.initState();
    _startHungerTimer();
  }

  void _startHungerTimer() {
    _hungerTimer?.cancel(); // guarantees exactly one hunger timer
    _hungerTimer = Timer.periodic(widget.hungerInterval, (timer) {
      if (!mounted || _finished) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_hunger + 5 > 100) {
          _hunger = 100;
          _happiness = _clampMeter(_happiness - 20);
        } else {
          _hunger += 5;
        }
      });
      _updateOutcome();
    });
  }

  void _updateOutcome() {
    if (_finished) return;

    if (_hunger == 100 && _happiness <= 10) {
      _highMoodTimer?.cancel();
      _highMoodTimer = null;
      _hungerTimer?.cancel();
      setState(() => _gameOver = true);
      return;
    }

    if (_happiness <= 80) {
      _highMoodTimer?.cancel();
      _highMoodTimer = null;
      return;
    }

    _highMoodTimer ??= Timer(widget.winDuration, () {
      _highMoodTimer = null;
      if (!mounted || _gameOver || _happiness <= 80) return;
      _hungerTimer?.cancel();
      setState(() => _hasWon = true);
    });
  }

  // ---- Actions ----
  void _play() {
    if (_finished) return;
    if (_energy < 10) {
      setState(() => _feedback = 'Too tired to play. Try Rest first.');
      _react('💤');
      return;
    }
    final nextHappiness = _clampMeter(_happiness + 15);
    final nextEnergy = _clampMeter(_energy - 15);
    final nextHunger = _clampMeter(_hunger + 10);
    setState(() {
      _happiness = nextHappiness;
      _energy = nextEnergy;
      _hunger = nextHunger;
      _feedback = 'Play: happiness +15, energy -15, hunger +10.';
    });
    _react('🎾');
    _updateOutcome();
  }

  void _feed() {
    if (_finished) return;
    final nextHunger = _clampMeter(_hunger - 10);
    final change = nextHunger < 30 ? -20 : 10; // overfed pets get cranky
    final nextHappiness = _clampMeter(_happiness + change);
    setState(() {
      _hunger = nextHunger;
      _happiness = nextHappiness;
      _feedback = change > 0
          ? 'Feed: hunger -10, happiness +10.'
          : 'Feed: hunger -10, but too full! Happiness -20.';
    });
    _react('🍖');
    _updateOutcome();
  }

  void _rest() {
    if (_finished) return;
    final nextEnergy = _clampMeter(_energy + 25);
    final nextHunger = _clampMeter(_hunger + 5);
    setState(() {
      _energy = nextEnergy;
      _hunger = nextHunger;
      _feedback = 'Rest: energy +25, hunger +5.';
    });
    _react('💤');
    _updateOutcome();
  }

  void _reset() {
    _highMoodTimer?.cancel();
    _highMoodTimer = null;
    _bounceTimer?.cancel();
    _reactionTimer?.cancel();
    setState(() {
      _happiness = 50;
      _hunger = 50;
      _energy = 70;
      _gameOver = false;
      _hasWon = false;
      _bouncing = false;
      _reaction = null;
      _feedback = 'Pet reset. Choose an action.';
    });
    _startHungerTimer();
  }

  void _confirmName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _petName = name;
      _feedback = 'Name set to $name.';
    });
    FocusScope.of(context).unfocus();
  }

  // ---- Short-lived animation helpers ----
  void _react(String emoji) {
    _bounceTimer?.cancel(); // newer action replaces older reset
    _reactionTimer?.cancel();
    setState(() {
      _bouncing = true;
      _reaction = emoji;
    });
    _bounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _bouncing = false);
    });
    _reactionTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _reaction = null);
    });
  }

  @override
  void dispose() {
    _hungerTimer?.cancel();
    _highMoodTimer?.cancel();
    _bounceTimer?.cancel();
    _reactionTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final bounceScale = (_bouncing && !reduceMotion) ? 1.12 : 1.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Pet')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _nameRow(),
              const SizedBox(height: 16),
              Center(child: _petImage(reduceMotion, bounceScale)),
              const SizedBox(height: 8),
              Center(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Mood: $_moodLabel',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _speechBubble(reduceMotion),
              const SizedBox(height: 16),
              _meter('Happiness', _happiness, Colors.green, reduceMotion),
              _meter('Hunger', _hunger, Colors.blue, reduceMotion),
              _meter('Energy', _energy, Colors.orange, reduceMotion),
              const SizedBox(height: 12),
              if (_gameOver) _banner('Game over. Press Reset to restart.'),
              if (_hasWon)
                _banner(
                  'You win! Happiness stayed high. Press Reset to play again.',
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: _finished ? null : _play,
                    child: const Text('Play'),
                  ),
                  FilledButton(
                    onPressed: _finished ? null : _feed,
                    child: const Text('Feed'),
                  ),
                  FilledButton(
                    onPressed: _finished ? null : _rest,
                    child: const Text('Rest'),
                  ),
                  OutlinedButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.blueGrey.shade50,
                child: Text(_feedback),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Pet name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _confirmName(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _confirmName, child: const Text('Confirm')),
      ],
    );
  }

  Widget _petImage(bool reduceMotion, double bounceScale) {
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        AnimatedScale(
          scale: _petScale * bounceScale,
          duration: duration,
          curve: Curves.easeOutBack,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(_moodColor, BlendMode.modulate),
            child: Image.asset(
              'assets/images/pet.png',
              width: 180,
              height: 180,
              semanticLabel: '$_petName the pet, feeling $_moodLabel',
              // Fallback so the app still runs before you add a PNG.
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.pets, size: 180, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          top: -8,
          child: AnimatedSlide(
            offset: _reaction == null || reduceMotion
                ? Offset.zero
                : const Offset(0, -0.4),
            duration: duration,
            child: AnimatedOpacity(
              opacity: _reaction == null ? 0 : 1,
              duration: duration,
              child: Text(
                _reaction ?? '',
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _speechBubble(bool reduceMotion) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        child: Text(
          _petMessage,
          key: ValueKey(_petMessage),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _meter(String label, int value, Color color, bool reduceMotion) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value / 100),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 12,
                color: color,
                semanticsLabel: '$label $value out of 100',
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('$value', textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _banner(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      color: _hasWon ? Colors.green.shade100 : Colors.red.shade100,
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
