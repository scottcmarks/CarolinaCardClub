import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carolina_card_club/realtimeclock.dart';
import 'package:carolina_card_club/database/database_helper.dart';

class SettingsBottomSheet extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); // key is necessary to access the NavigatorState

  SettingsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Initially disable system back gestures
      onPopInvoked: (didPop) async {
        if (didPop) {
          return; // Pop already happened, do nothing
        }
        final NavigatorState? childNavigator = navigatorKey.currentState;
        if (childNavigator != null && childNavigator.canPop()) {
          childNavigator.pop();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            AppBar(
              title: const Text('Nested Navigation'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  if (navigatorKey.currentState?.canPop() ?? false) {
                    navigatorKey.currentState?.pop();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
            Expanded(
              child: Navigator(
                key: navigatorKey, // key is necessary to access the NavigatorState
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (context) => const SettingsPage1(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class SettingsPage1 extends StatefulWidget {
  const SettingsPage1({super.key});

  @override
  State<SettingsPage1> createState() => _SettingsPage1State();
}

class _SettingsPage1State extends State<SettingsPage1> {
  // Although the SwitchListTile value comes from a Provider,
  // we might want a local variable to temporarily hold the value
  // if the update is not meant to be immediate or there's
  // some intermediate logic. However, for a direct update,
  // we can rely solely on the Provider.
  // bool _localSwitchValue = false;

  @override
  void initState() {
    super.initState();
    // You can initialize _localSwitchValue here if needed,
    // potentially fetching the current value from the Provider.
    // _localSwitchValue = Provider.of<DatabaseHelper>(context, listen: false).showingOnlyActiveSessions();
  }

  @override
  Widget build(BuildContext context) {
    // You can listen to changes here if you need to react to them
    // within the build method, or you can use Consumer widgets
    // for more fine-grained control over rebuilds.
    // final databaseHelper = Provider.of<DatabaseHelper>(context); // listening
    // final timeProvider = Provider.of<TimeProvider>(context); // listening

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Settings'),
        ElevatedButton(
          child: const Text('Set Clock'),
          onPressed: () {
            // Accessing Provider without listening for changes (good for events)
            Provider.of<TimeProvider>(context, listen: false).userSetClock(DateTime(2026, 1, 27, 19, 30, 30));
          },
        ),
        // By using Consumer, only the SwitchListTile will rebuild
        // when DatabaseHelper changes, not the entire SettingsPage1.
        Consumer<DatabaseHelper>(
          builder: (context, databaseHelper, child) {
            return SwitchListTile(
              title: const Text('Show only active sessions'),
              value: databaseHelper.showingOnlyActiveSessions(),
              onChanged: (bool newValue) {
                // When newValue changes, update the Provider's state.
                // Since DatabaseHelper is a ChangeNotifier, it will call notifyListeners(),
                // and the Consumer will automatically rebuild this SwitchListTile.
                databaseHelper.updateShowingOnlyActiveSessions(newValue);
              },
            );
          },
        ),
      ],
    );
  }
}
