import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../models/secrets.dart';

class FeedbackService {
  // Constants for reporting
  // WARNING: In a real app, these should not be hardcoded.
  // Use environment variables or a backend service.

  // Send feedback email from devices silently; on web, open the default email client
  static Future<bool> sendErrorReport({
    required String messageText,
    String? word,
    String? context,
  }) async {
    sendFeedbackEmail(String messageText) {
      String encodeQueryParameters(Map<String, String> params) {
        return params.entries
            .map(
              (e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
            )
            .join('&');
      }

      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: recipientEmail,
        query: encodeQueryParameters({
          'subject': 'Wure Kaŋ-fóore Feedback',
          'body': messageText,
        }),
      );

      launchUrl(emailLaunchUri);
    }

    final String fullMessage =
        '''
Baat: ${word ?? 'N/A'}
Melo: ${context ?? 'General'}
Bataaxal:
$messageText
''';

    if (kIsWeb) {
      sendFeedbackEmail(fullMessage);
      return false;
    }

    final smtpServer = hotmail(senderEmail, senderPassword);

    final message = Message()
      ..from = Address(senderEmail, 'Wure Kaŋ-fóore Error Reporting')
      ..recipients.add(recipientEmail)
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
