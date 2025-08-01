import 'package:flutter/foundation.dart';
import 'package:untitled/models/user_model.dart';
import 'package:untitled/repositories/user_repository.dart';
import 'package:untitled/services/connectivity_service.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _userRepo = UserRepository();

  // State variables
  bool _isLoading = false;
  UserModel? _currentUser;
  List<UserModel> _users = [];
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;
  List<UserModel> get users => _users;
  List<UserModel> get activeUsers =>
      _users.where((user) => user.isActive).toList();
  List<UserModel> get inactiveUsers =>
      _users.where((user) => !user.isActive).toList();
  String? get error => _error;

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Get users by role
  List<UserModel> getUsersByRole(String role) {
    return _users.where((user) => user.role == role).toList();
  }

  List<UserModel> getActiveUsersByRole(String role) {
    return _users.where((user) => user.role == role && user.isActive).toList();
  }

  // Create user (admin pre-registration)
  Future<bool> createUser(UserModel user) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      await _userRepo.createUser(user);
      // Refresh the users list to get the updated user with generated IDs
      await loadAllUsers();
      _setLoading(false);
      return true;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      _setLoading(false);
      return false;
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return null;
    }

    _setLoading(true);
    _setError(null);

    try {
      final user = await _userRepo.getUserById(userId);
      _currentUser = user;
      _setLoading(false);
      return user;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      _setLoading(false);
      return null;
    }
  }

  // Get user by ID without triggering state changes (for use in build methods)
  Future<UserModel?> getUserByIdSilent(String userId) async {
    try {
      final user = await _userRepo.getUserById(userId);
      return user;
    } catch (e) {
      return null;
    }
  }

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return null;
    }

    _setLoading(true);
    _setError(null);

    try {
      final user = await _userRepo.getUserByEmail(email);
      _setLoading(false);
      return user;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      _setLoading(false);
      return null;
    }
  }

  // Load all users
  Future<void> loadAllUsers() async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      _users = await _userRepo.getAllUsers();
      _setLoading(false);
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      _setLoading(false);
    }
  }

  // Load users by role from repository
  Future<void> loadUsersByRole(String role) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final roleUsers = await _userRepo.getAllUsersByRole(role);
      // Update only users of this role in the main list
      _users.removeWhere((user) => user.role == role);
      _users.addAll(roleUsers);
      _setLoading(false);
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      _setLoading(false);
    }
  }

  // Update user
  Future<bool> updateUser(UserModel user) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      await _userRepo.updateUser(user);

      // Update current user if it's the same
      if (_currentUser?.id == user.id) {
        _currentUser = user;
      }

      // Update in users list
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        _users[index] = user;
      }

      _setLoading(false);
      return true;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      _setLoading(false);
      return false;
    }
  }

  // Activate user (during sign up)
  Future<bool> activateUser(String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _userRepo.activateUser(userId);

      // Update local state
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(isActive: true);
      }

      // Update current user if it's the same
      if (_currentUser?.id == userId) {
        _currentUser = _currentUser!.copyWith(isActive: true);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Deactivate user (admin action)
  Future<bool> deactivateUser(String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _userRepo.deactivateUser(userId);

      // Update local state
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(isActive: false);
      }

      // Update current user if it's the same
      if (_currentUser?.id == userId) {
        _currentUser = _currentUser!.copyWith(isActive: false);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Delete user
  Future<bool> deleteUser(String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _userRepo.deleteUser(userId);

      // Remove from local list
      _users.removeWhere((u) => u.id == userId);

      // Clear current user if it's the deleted one
      if (_currentUser?.id == userId) {
        _currentUser = null;
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Check if user exists by email
  Future<bool> userExistsByEmail(String email) async {
    try {
      return await _userRepo.userExistsByEmail(email);
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Set current user (for login/session management)
  void setCurrentUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all data (for logout)
  void clearData() {
    _currentUser = null;
    _users.clear();
    _error = null;
    notifyListeners();
  }
}
