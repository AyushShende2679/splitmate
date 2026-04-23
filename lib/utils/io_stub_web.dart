// Web stub for dart:io classes
// Provides empty implementations so code compiles on web

class File {
  final String path;
  File(this.path);
  Future<File> writeAsBytes(List<int> bytes) async => this;
  Future<File> writeAsString(String contents) async => this;
  Future<bool> exists() async => false;
  bool existsSync() => false;
}

class Directory {
  final String path;
  Directory(this.path);
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
}

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
}
