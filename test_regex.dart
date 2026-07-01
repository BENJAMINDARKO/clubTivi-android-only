void main() {
  final extInf1 = '#EXTINF:-1 tvg-id="ESPN.us" group-title="Sports",ESPN HD';
  final extInf2 = '#EXTINF:-1 tvg-id=ESPN.us group-title=Sports,ESPN HD';
  
  final regex = RegExp(r'([\w-]+)=(?:"([^"]*)"|([^"\s,]+))');
  
  print("1:");
  for (final match in regex.allMatches(extInf1)) {
    print('${match.group(1)} = ${match.group(2) ?? match.group(3)}');
  }
  
  print("2:");
  for (final match in regex.allMatches(extInf2)) {
    print('${match.group(1)} = ${match.group(2) ?? match.group(3)}');
  }
}
