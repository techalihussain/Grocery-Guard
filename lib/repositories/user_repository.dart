import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // Create a new user (for admin pre-registration) - defaults to inactive
  Future<void> createUser(UserModel user) async {
    try {
      // Generate document ID
      final docRef = _firestore.collection(_collection).doc();
      
      // Auto-generate employee ID or account number based on role
      UserModel updatedUser = user.copyWith(id: docRef.id);
      
      if (user.role == 'salesman' || user.role == 'storeuser') {
        final employeeId = await _generateEmployeeId();
        updatedUser = updatedUser.copyWith(employeeId: employeeId);
      } else if (user.role == 'customer' || user.role == 'vendor') {
        final accountNo = await _generateAccountNumber();
        updatedUser = updatedUser.copyWith(accountNo: accountNo);
      }
      
      await docRef.set(updatedUser.toMap());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // Generate auto-incremented employee ID
  Future<String> _generateEmployeeId() async {
    try {
      // Get all users with employee IDs
      final query = await _firestore
          .collection(_collection)
          .where('employeeId', isNull: false)
          .get();
      
      // Find the highest employee number
      int maxNumber = 0;
      for (var doc in query.docs) {
        final employeeId = doc.data()['employeeId'] as String?;
        if (employeeId != null && employeeId.startsWith('EMP-')) {
          final numberStr = employeeId.substring(4);
          final number = int.tryParse(numberStr) ?? 0;
          if (number > maxNumber) {
            maxNumber = number;
          }
        }
      }
      
      // Generate next employee ID
      final nextNumber = maxNumber + 1;
      return 'EMP-${nextNumber.toString().padLeft(2, '0')}';
    } catch (e) {
      throw Exception('Failed to generate employee ID: $e');
    }
  }

  // Generate auto-incremented account number
  Future<String> _generateAccountNumber() async {
    try {
      // Get all users with account numbers
      final query = await _firestore
          .collection(_collection)
          .where('accountNo', isNull: false)
          .get();
      
      // Find the highest account number
      int maxNumber = 0;
      for (var doc in query.docs) {
        final accountNo = doc.data()['accountNo'] as String?;
        if (accountNo != null && accountNo.startsWith('ACCNO-')) {
          final numberStr = accountNo.substring(6);
          final number = int.tryParse(numberStr) ?? 0;
          if (number > maxNumber) {
            maxNumber = number;
          }
        }
      }
      
      // Generate next account number
      final nextNumber = maxNumber + 1;
      return 'ACCNO-${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      throw Exception('Failed to generate account number: $e');
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Get user by email (useful for login validation)
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return UserModel.fromJson(query.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user by email: $e');
    }
  }

  // Get active users by role (for operational use)
  Future<List<UserModel>> getActiveUsersByRole(String role) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: role)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      
      return query.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to get active users by role: $e');
    }
  }

  // Get all users by role (including inactive - for admin management)
  Future<List<UserModel>> getAllUsersByRole(String role) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: role)
          .orderBy('createdAt', descending: true)
          .get();
      
      return query.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to get users by role: $e');
    }
  }

  // Get inactive users (for admin to see who hasn't signed up yet)
  Future<List<UserModel>> getInactiveUsers() async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();
      
      return query.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to get inactive users: $e');
    }
  }

  // Find user document by email (since ID might have changed after signup)
  Future<String?> _findUserDocumentId(String userIdOrEmail) async {
    try {
      // First try with the provided ID
      final docById = await _firestore.collection(_collection).doc(userIdOrEmail).get();
      if (docById.exists) {
        return userIdOrEmail;
      }
      
      // If not found, search by email
      final queryByEmail = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: userIdOrEmail)
          .limit(1)
          .get();
      
      if (queryByEmail.docs.isNotEmpty) {
        return queryByEmail.docs.first.id;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // Activate user (called during sign up process)
  Future<void> activateUser(String userId) async {
    try {
      final actualDocId = await _findUserDocumentId(userId);
      if (actualDocId == null) {
        throw Exception('User document not found');
      }
      
      await _firestore.collection(_collection).doc(actualDocId).update({
        'isActive': true,
      });
    } catch (e) {
      throw Exception('Failed to activate user: $e');
    }
  }

  // Deactivate user (for admin to disable access)
  Future<void> deactivateUser(String userId) async {
    try {
      final actualDocId = await _findUserDocumentId(userId);
      if (actualDocId == null) {
        throw Exception('User document not found');
      }
      
      await _firestore.collection(_collection).doc(actualDocId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to deactivate user: $e');
    }
  }

  // Update user information
  Future<void> updateUser(UserModel user) async {
    try {
      final actualDocId = await _findUserDocumentId(user.id);
      if (actualDocId == null) {
        // Try finding by email as fallback
        final docIdByEmail = await _findUserDocumentId(user.email);
        if (docIdByEmail == null) {
          throw Exception('User document not found');
        }
        await _firestore.collection(_collection).doc(docIdByEmail).update(user.toMap());
      } else {
        await _firestore.collection(_collection).doc(actualDocId).update(user.toMap());
      }
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    try {
      final actualDocId = await _findUserDocumentId(userId);
      if (actualDocId == null) {
        throw Exception('User document not found');
      }
      
      await _firestore.collection(_collection).doc(actualDocId).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Get all active users (for operational views)
  Future<List<UserModel>> getAllActiveUsers() async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      
      return query.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to get active users: $e');
    }
  }

  // Get all users (for admin overview)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final query = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();
      
      return query.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to get all users: $e');
    }
  }

  // Check if user exists by email (for pre-registration validation)
  Future<bool> userExistsByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check user existence: $e');
    }
  }

  // Stream user data (for real-time updates)
  Stream<UserModel?> streamUser(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    });
  }

  // Stream active users by role (for real-time operational lists)
  Stream<List<UserModel>> streamActiveUsersByRole(String role) {
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: role)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) => 
            query.docs.map((doc) => UserModel.fromJson(doc.data())).toList());
  }

  // Stream all users by role (for admin management)
  Stream<List<UserModel>> streamAllUsersByRole(String role) {
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: role)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) => 
            query.docs.map((doc) => UserModel.fromJson(doc.data())).toList());
  }
}