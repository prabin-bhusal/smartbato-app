import 'package:http/http.dart' as http;

http.Client createPinnedInnerClient() {
  return http.Client();
}
