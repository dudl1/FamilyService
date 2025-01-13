import 'dart:convert';
import 'package:flutter/services.dart';

Future<String> host_helper(String dir) async {
  Map<String, dynamic> config = json.decode(await rootBundle.loadString('assets/host_helper.json'));
  
  String url = config['host'] == 'local'
    ? '${config['local_ip']}:${config['local_port']}${config['dir'][0][dir]}'
    : '${config['global']}${config['dir'][0][dir]}';

  return url;
}