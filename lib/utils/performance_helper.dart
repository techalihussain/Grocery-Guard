import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PerformanceHelper {
  static Timer? _debounceTimer;
  
  /// Debounce function calls to prevent excessive operations
  static void debounce(VoidCallback callback, {Duration delay = const Duration(milliseconds: 300)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }
  
  /// Run heavy operations on a separate isolate to avoid blocking UI
  static Future<T> runInBackground<T>(T Function(dynamic) computation, [dynamic message]) async {
    return await compute(computation, message);
  }
  
  /// Helper method for simple computations without parameters
  static Future<T> runSimpleInBackground<T>(T Function() computation) async {
    return await compute(_simpleComputation<T>, computation);
  }
  
  static T _simpleComputation<T>(T Function() computation) {
    return computation();
  }
  
  /// Optimize system UI for better performance
  static void optimizeSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }
  
  /// Reduce memory pressure by clearing caches
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
  
  /// Optimize for low-end devices
  static void optimizeForLowEndDevices() {
    // Reduce image cache size for low-end devices
    PaintingBinding.instance.imageCache.maximumSize = 50;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50MB
  }
}