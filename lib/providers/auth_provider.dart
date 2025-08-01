import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../services/connectivity_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _initializeAuthListener();
  }

  // Initialize Firebase Auth state listener
  void _initializeAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isInitialized = true;
      notifyListeners();
    });
  }

  Future<String?> signup(String email, String password) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _error = "No internet connection. Please check your connection and try again.";
      notifyListeners();
      return null;
    }

    _isLoading = true;
    clear();
    notifyListeners();

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _error = "You are not pre-registered. Please contact admin.";
        _isLoading = false;
        notifyListeners();
        return null;
      }

      DocumentSnapshot preRegisterDoc = snapshot.docs.first;
      Map<String, dynamic> preData =
          preRegisterDoc.data() as Map<String, dynamic>;
      String role = preData['role'];

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User newUser = userCredential.user!;
      await newUser.sendEmailVerification();
      await newUser.reload();
      await _auth.signOut();

      _user = null;

      await _firestore.collection('users').doc(preRegisterDoc.id).delete();
      await _firestore.collection('users').doc(newUser.uid).set({
        ...preData,
        'id': newUser.uid,
        'isActive': true,
      });
      _isLoading = false;
      notifyListeners();
      return role;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _error = "Connection lost. Please check your internet connection and try again.";
      } else {
        _error = "Something went wrong: ${e.toString()}";
      }
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<String?> signin(String email, String password) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _error = "No internet connection. Please check your connection and try again.";
      notifyListeners();
      return null;
    }

    // Clear any previous errors
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;

      if (!_user!.emailVerified) {
        await verify();
        _error = "Please verify your email before signing in";
        await _auth.signOut();
        _user = null;
        _isLoading = false;
        notifyListeners();
        return null;
      }

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_user!.uid)
          .get();

      if (!userDoc.exists) {
        _error = "No user data found.";
        await _auth.signOut();
        _user = null;
        _isLoading = false;
        notifyListeners();
        return null;
      }

      String role = userDoc.get('role');
      _isLoading = false;
      notifyListeners();
      return role;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      await _auth.signOut(); // Ensure user is signed out on error
      _user = null;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _error = "Connection lost. Please check your internet connection and try again.";
      } else {
        _error = "Something went wrong: ${e.toString()}";
      }
      await _auth.signOut(); // Ensure user is signed out on error
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<String?> checkAuthAndGetRole() async {
    // Wait for auth to be initialized
    if (!_isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isInitialized) return null;
    }

    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _error = "No internet connection. Please check your connection and try again.";
      notifyListeners();
      return null;
    }

    // Clear any previous errors
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Reload user to get latest email verification status
      await currentUser.reload();
      final refreshedUser = _auth.currentUser;

      if (refreshedUser == null || !refreshedUser.emailVerified) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final doc = await _firestore
          .collection('users')
          .doc(refreshedUser.uid)
          .get();
      
      if (!doc.exists) {
        _error = "User data not found.";
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _user = refreshedUser;
      final role = doc.get('role');
      _isLoading = false;
      notifyListeners();
      return role;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _error = "Connection lost. Please check your internet connection and try again.";
      } else {
        _error = "Something went wrong: ${e.toString()}";
      }
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Get user role from Firestore (helper method)
  Future<String?> getUserRole() async {
    if (_user == null) return null;
    
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        return doc.get('role');
      }
    } catch (e) {
      debugPrint('Error getting user role: $e');
    }
    return null;
  }

  Future<void> verify() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_auth.currentUser != null && !_auth.currentUser!.emailVerified) {
        await _auth.currentUser!.sendEmailVerification();
        _user = _auth.currentUser;
      }
    } on FirebaseAuthException catch (e) {
      _error = e.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _error = "No internet connection. Please check your connection and try again.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    clear();
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _error = "Connection lost. Please check your internet connection and try again.";
      } else {
        _error = "Something went wrong: ${e.toString()}";
      }
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void clear() {
    _error = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _auth.signOut();
    _user = null;

    _isLoading = false;
    notifyListeners();
  }
}
