import 'dart:convert';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';


class LoggerService extends GetxService {
   Logger logger = Logger();

  @override
 
  Future<void>  onInit()  async{
    super.onInit();
    await LogWriter.init();  // Initialize Logs folder

    logger = Logger(
      level: Level.all,// kReleaseMode ? Level.all : Level.debug,
      printer: PrettyPrinter(methodCount: 0),
      output: _DailyFileOutput(),  // Custom output to daily file
    );
  }

  // Helper methods
  void debug(String? message) => logger.d(message);
  void info(String? message) => logger.i(message);
  void warning(String? message) => logger.w(message);
  void error(String? message, {dynamic error, StackTrace? stackTrace}) => 
      logger.e(message, error: error, stackTrace: stackTrace);
      
}
class _DailyFileOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Print to console
    event.lines.forEach(print);

    // Write to today's log file
    event.lines.forEach((line) {
      LogWriter.write(line).catchError((e) => print("Log write error: $e"));
    });
  }
}


class LogWriter {
  static Directory? _logDir;
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss.SSS');

  /// Initialize logs directory (call once at app startup)
  static Future<void> init() async {
    try {
      if (_logDir != null) return;
      // Use app documents directory for safe, permission-free logging
      final Directory baseDir = await getApplicationDocumentsDirectory();
      final Directory folder = Directory('${baseDir.path}/logs');
      _logDir = folder;
      if (!await folder.exists()) {
        await folder.create(recursive: true);
        print('Folder created at: ${folder.path}');
      } else {
        print('Folder already exists at: ${folder.path}');
      }
//         }
//       }
    
    } catch (e) {
      stderr.writeln('Failed to initialize log directory: $e');
      rethrow;
    }
  }
 Future<void> createFolderInSharedDocuments(String folderName) async {
      // Get the external storage directories (including Shared Documents)
      List<String> directories = (await getExternalStorageDirectories())!
          .whereType<Directory>()
          .map((d) => d.path)
          .toList();

      // Iterate through the directories to find Shared Documents
      for (var dir in directories) {
        // Check if the directory path contains "Documents" (or similar term)
        if (dir.toLowerCase().contains("documents") ||
            dir.toLowerCase().contains("downloads") ||
            dir.toLowerCase().contains("shared")) {
          // Construct the full path to your folder
          String folderPath = '$dir/$folderName';

          // Create the directory
          final Directory folder = Directory(folderPath);
            _logDir = folder;
          if (!await folder.exists()) {
            await folder.create(recursive: true);
            print('Folder created at: $folderPath');
          } else {
            print('Folder already exists at: $folderPath');
          }
        }
      }
    }
  /// Get today's log file (creates if missing)
  static Future<File> _getTodayLogFile() async {
    if (_logDir == null) await init();
    final String today = _dateFormat.format(DateTime.now());
    return File('${_logDir!.path}/$today.log');
  }

  /// Write a log entry to today's file
  static Future<void> write(String message) async {
    try {
      final File file = await _getTodayLogFile();
      await file.writeAsString(
        '${_timeFormat.format(DateTime.now())}: $message',
        mode: FileMode.append,
        encoding: utf8,
      );
    } catch (e) {
      stderr.writeln("Failed to write log: $e");
    }
  }

  /// Read today's logs
  static Future<String> readTodayLogs() async {
    try {
      final File file = await _getTodayLogFile();
      return file.existsSync() ? await file.readAsString() : "No logs today";
    } catch (e) {
      stderr.writeln("Failed to read logs: $e");
      return "Error reading logs";
    }
  }

  /// List all log files (sorted by date, newest first)
  static Future<List<File>> listLogFiles() async {
    try {
      if (_logDir == null) await init();
      return _logDir!
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.log'))
          .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    } catch (e) {
      stderr.writeln("Failed to list log files: $e");
      return [];
    }
  }

  /// Clear all log files
  static Future<void> clearLogs() async {
    try {
      if (_logDir == null) await init();
      final files = await listLogFiles();
      for (final file in files) {
        await file.delete();
      }
    } catch (e) {
      stderr.writeln("Failed to clear logs: $e");
    }
  }
}

