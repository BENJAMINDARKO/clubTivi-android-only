import 'dart:core';

void main() {
  var url = 'http://server.com/movie/john/password/123.mp4';
  var ext = url.split('?').first.split('.').last.toLowerCase();
  print(ext);
}
