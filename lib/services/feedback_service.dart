import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class FeedbackService {
  // Constants for reporting
  // WARNING: In a real app, these should not be hardcoded.
  // Use environment variables or a backend service.
  static const String _senderEmail = 'your-email@hotmail.com';
  static const String _senderPassword = 'your-password';
  static const String _recipientEmail = 'recipient-email@destination.com';

  static Future<bool> sendErrorReport({
    required String messageText,
    String? word,
    String? context,
  }) async {
    final smtpServer = hotmail(_senderEmail, _senderPassword);

    final String fullMessage = '''
Word: ${word ?? 'N/A'}
Context: ${context ?? 'General'}
User Message:
$messageText
''';

    final message = Message()
      ..from = const Address(_senderEmail, 'Wure Kaŋ-fóore Error Reporting')
      ..recipients.add(_recipientEmail)
      ..subject = 'Wure Kaŋ-fóore Error Report${word != null ? ": $word" : ""}'
      ..text = fullMessage;

    try {
      final sendReport = await send(message, smtpServer);
      if (kDebugMode) debugPrint('Message sent: $sendReport');
      return true;
    } on MailerException catch (e) {
      if (kDebugMode) debugPrint('Message not sent: $e');
      for (var p in e.problems) {
        if (kDebugMode) debugPrint('Problem: ${p.code}: ${p.msg}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Unexpected error sending email: $e');
      return false;
    }
  }
}
