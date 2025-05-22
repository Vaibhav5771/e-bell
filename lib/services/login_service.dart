class LoginService {
  // Hardcoded credentials
  final String _correctUserId = '123';
  final String _correctPassword = '123';

  // Method to validate login credentials
  bool validateCredentials(String userId, String password) {
    return userId == _correctUserId && password == _correctPassword;
  }
}