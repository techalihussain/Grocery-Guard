import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final bool showOfflineIndicator;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.showOfflineIndicator = true,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with ConnectivityMixin {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService().connectivityStream,
      initialData: ConnectivityService().isConnected,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            widget.child,
            if (!isConnected && widget.showOfflineIndicator)
              _buildOfflineIndicator(),
          ],
        );
      },
    );
  }

  Widget _buildOfflineIndicator() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No internet connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final isConnected = await ConnectivityService()
                        .checkConnection();
                    if (!isConnected && mounted) {
                      ConnectivityService.showNoInternetDialog(context);
                    }
                  },
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Loading overlay for network operations
class NetworkLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? loadingMessage;

  const NetworkLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (loadingMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          loadingMessage!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Button that checks connectivity before executing action
class ConnectivityAwareButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool showDialogOnNoConnection;

  const ConnectivityAwareButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.showDialogOnNoConnection = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      onPressed: onPressed == null
          ? null
          : () async {
              final isConnected = ConnectivityService().isConnected;

              if (!isConnected) {
                if (showDialogOnNoConnection) {
                  ConnectivityService.showNoInternetDialog(
                    context,
                    onRetry: onPressed,
                  );
                } else {
                  ConnectivityService.showConnectionLostSnackBar(context);
                }
                return;
              }

              onPressed!();
            },
      child: child,
    );
  }
}

// IconButton that checks connectivity
class ConnectivityAwareIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final bool showDialogOnNoConnection;

  const ConnectivityAwareIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.showDialogOnNoConnection = true,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed == null
          ? null
          : () async {
              final isConnected = ConnectivityService().isConnected;

              if (!isConnected) {
                if (showDialogOnNoConnection) {
                  ConnectivityService.showNoInternetDialog(
                    context,
                    onRetry: onPressed,
                  );
                } else {
                  ConnectivityService.showConnectionLostSnackBar(context);
                }
                return;
              }

              onPressed!();
            },
      icon: icon,
    );
  }
}

// FloatingActionButton that checks connectivity
class ConnectivityAwareFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;
  final bool showDialogOnNoConnection;

  const ConnectivityAwareFAB({
    super.key,
    required this.onPressed,
    required this.child,
    this.tooltip,
    this.showDialogOnNoConnection = true,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      tooltip: tooltip,
      onPressed: onPressed == null
          ? null
          : () async {
              final isConnected = ConnectivityService().isConnected;

              if (!isConnected) {
                if (showDialogOnNoConnection) {
                  ConnectivityService.showNoInternetDialog(
                    context,
                    onRetry: onPressed,
                  );
                } else {
                  ConnectivityService.showConnectionLostSnackBar(context);
                }
                return;
              }

              onPressed!();
            },
      child: child,
    );
  }
}
