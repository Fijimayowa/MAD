import 'package:flutter/material.dart';

import 'fcm_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FCMService _fcm = FCMService();

  @override
  void initState() {
    super.initState();
    _fcm.initialize();
  }

  @override
  void dispose() {
    _fcm.dispose(); // cancels listeners
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FCM Demo')),
      body: ListenableBuilder(
        listenable: _fcm,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _fcm.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              // Safe: _fcm.asset is only ever 'default' or 'promo'.
              Image.asset('assets/images/${_fcm.asset}.png', height: 200),
              const SizedBox(height: 16),
              if (_fcm.diagnostic != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_fcm.diagnostic!),
                  ),
                ),
              const Divider(height: 32),
              Text('Last handler: ${_fcm.lastHandler}'),
              Text('Receipts this launch: ${_fcm.receiptCount}'),
              Text('Message ID: ${_fcm.messageId ?? "-"}'),
              Text('Permission: ${_fcm.permissionStatus}'),
            ],
          );
        },
      ),
    );
  }
}
