import 'package:local_auth/local_auth.dart';

/// Windows Hello / biometric gate.
abstract class BiometricAuth {
  Future<bool> canCheckBiometrics();
  Future<bool> isDeviceSupported();
  Future<bool> authenticate({required String reason});
}

class LocalBiometricAuth implements BiometricAuth {
  LocalBiometricAuth({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canCheckBiometrics() => _auth.canCheckBiometrics;

  @override
  Future<bool> isDeviceSupported() => _auth.isDeviceSupported();

  @override
  Future<bool> authenticate({required String reason}) {
    return _auth.authenticate(
      localizedReason: reason,
      biometricOnly: false,
    );
  }
}

class FakeBiometricAuth implements BiometricAuth {
  FakeBiometricAuth({this.supported = true, this.succeed = true});

  bool supported;
  bool succeed;
  int authenticateCalls = 0;

  @override
  Future<bool> canCheckBiometrics() async => supported;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    return succeed;
  }
}
