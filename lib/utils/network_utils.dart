import 'package:http/http.dart' as http;

class NetworkUtils {
  post(Map<String, dynamic> body, String url) async {
    http.Response res = await http.post(Uri.parse(url));
    return res;
  }

  get(String params, String url) async {
    http.Response res = await http.get(Uri.parse(
      url + params,
    ));
    return res;
  }
}
