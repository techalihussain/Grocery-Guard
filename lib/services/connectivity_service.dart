import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  // Stream controller for connectivity changes
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  // Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    await _checkConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      await _checkConnectivity();
    });
  }

  // Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final List<ConnectivityResult> connectivityResults = await _connectivity
          .checkConnectivity();

      if (connectivityResults.contains(ConnectivityResult.none)) {
        _updateConnectionStatus(false);
        return;
      }

      // Even if we have connectivity, let's verify with a real internet check
      final bool hasInternet = await _hasInternetConnection();
      _updateConnectionStatus(hasInternet);
    } catch (e) {
      _updateConnectionStatus(false);
    }
  }

  // Verify actual internet connection by trying to reach a reliable server
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Update connection status and notify listeners
  void _updateConnectionStatus(bool isConnected) {
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      _connectivityController.add(_isConnected);
    }
  }

  // Manual connectivity check
  Future<bool> checkConnection() async {
    await _checkConnectivity();
    return _isConnected;
  }

  // Show no internet dialog
  static void showNoInternetDialog(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text('No Internet Connection', maxLines: 2)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please check your internet connection and try again.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Troubleshooting:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Check your WiFi or mobile data\n'
                      '• Try turning airplane mode on/off\n'
                      '• Restart your router if using WiFi',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // Show loading while checking
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Checking connection...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                // Check connection
                final isConnected = await ConnectivityService()
                    .checkConnection();

                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading dialog

                  if (isConnected) {
                    if (onRetry != null) {
                      onRetry();
                    }
                  } else {
                    // Still no connection, show dialog again
                    showNoInternetDialog(context, onRetry: onRetry);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  // Show connection restored snackBar
  static void showConnectionRestoredSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi, color: Colors.white),
            SizedBox(width: 12),
            Text('Internet connection restored'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Show connection lost snackBar
  static void showConnectionLostSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 12),
            Text('Internet connection lost'),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () async {
            final isConnected = await ConnectivityService().checkConnection();
            if (!isConnected && context.mounted) {
              showNoInternetDialog(context);
            }
          },
        ),
      ),
    );
  }

  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}

// Mixin for easy connectivity handling in widgets
mixin ConnectivityMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<bool>? _connectivitySubscription;
  bool _wasConnected = true;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = ConnectivityService().connectivityStream.listen(
      (bool isConnected) {
        if (mounted) {
          if (!isConnected && _wasConnected) {
            // Connection lost
            onConnectionLost();
          } else if (isConnected && !_wasConnected) {
            // Connection restored
            onConnectionRestored();
          }
          _wasConnected = isConnected;
        }
      },
    );
  }

  // Override these methods in your widgets
  void onConnectionLost() {
    ConnectivityService.showConnectionLostSnackBar(context);
  }

  void onConnectionRestored() {
    ConnectivityService.showConnectionRestoredSnackBar(context);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

// Helper function to execute network operations with connectivity check
Future<T?> executeWithConnectivity<T>(
  BuildContext context,
  Future<T> Function() operation, {
  VoidCallback? onRetry,
  bool showDialog = true,
}) async {
  final connectivityService = ConnectivityService();

  if (!connectivityService.isConnected) {
    if (showDialog) {
      ConnectivityService.showNoInternetDialog(
        context,
        onRetry:
            onRetry ??
            () => executeWithConnectivity(context, operation, onRetry: onRetry),
      );
    }
    return null;
  }

  try {
    return await operation();
  } catch (e) {
    // Check if error is due to connectivity
    final isConnected = await connectivityService.checkConnection();
    if (!isConnected && context.mounted) {
      if (showDialog) {
        ConnectivityService.showNoInternetDialog(
          context,
          onRetry:
              onRetry ??
              () =>
                  executeWithConnectivity(context, operation, onRetry: onRetry),
        );
      }
      return null;
    }
    rethrow; // Re-throw if it's not a connectivity issue
  }
}
