import 'package:nb_utils/nb_utils.dart';

class SharedPrefUtil {
  SharedPrefUtil._();

  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  static set(int val) async {
    await prefs.setInt('counter', val);
  }

  static int? getVal() {
    return prefs.getInt('counter');
  }
}
