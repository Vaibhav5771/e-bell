import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';

class AppAlert {
  /// ✅ General-purpose show function
  static void show(
      BuildContext context, {
        required QuickAlertType type,
        String? title,
        String? text,
        String confirmBtnText = 'OK',
        Color? confirmBtnColor,
        bool barrierDismissible = true,
        VoidCallback? onConfirm,
      }) {
    QuickAlert.show(
      context: context,
      type: type,
      title: title ?? _defaultTitle(type),
      text: text ?? _defaultMessage(type),
      confirmBtnText: confirmBtnText,
      confirmBtnColor: confirmBtnColor ?? _defaultColor(type),
      backgroundColor: Colors.white,
      barrierDismissible: barrierDismissible,
      onConfirmBtnTap: onConfirm,
    );
  }

  /// ✅ Quick shortcut methods (optional convenience)
  static void success(BuildContext context, {String? title, String? text}) =>
      show(context, type: QuickAlertType.success, title: title, text: text);

  static void error(BuildContext context, {String? title, String? text}) =>
      show(context, type: QuickAlertType.error, title: title, text: text);

  static void warning(BuildContext context, {String? title, String? text}) =>
      show(context, type: QuickAlertType.warning, title: title, text: text);

  static void info(BuildContext context, {String? title, String? text}) =>
      show(context, type: QuickAlertType.info, title: title, text: text);

  static void confirm(
      BuildContext context, {
        String? title,
        String? text,
        VoidCallback? onConfirm,
      }) =>
      show(
        context,
        type: QuickAlertType.confirm,
        title: title,
        text: text,
        onConfirm: onConfirm,
      );

  static void loading(BuildContext context, {String? title, String? text}) =>
      show(context, type: QuickAlertType.loading, title: title, text: text);

  /// ✅ Default values
  static String _defaultTitle(QuickAlertType type) {
    switch (type) {
      case QuickAlertType.success:
        return 'Success!';
      case QuickAlertType.error:
        return 'Error!';
      case QuickAlertType.warning:
        return 'Warning!';
      case QuickAlertType.info:
        return 'Information';
      case QuickAlertType.confirm:
        return 'Confirm';
      case QuickAlertType.loading:
        return 'Loading...';
      default:
        return 'Alert';
    }
  }

  static String _defaultMessage(QuickAlertType type) {
    switch (type) {
      case QuickAlertType.success:
        return 'Operation completed successfully!';
      case QuickAlertType.error:
        return 'Something went wrong.';
      case QuickAlertType.warning:
        return 'Please be cautious.';
      case QuickAlertType.info:
        return 'Here’s some information.';
      case QuickAlertType.confirm:
        return 'Are you sure you want to proceed?';
      case QuickAlertType.loading:
        return 'Please wait a moment...';
      default:
        return '';
    }
  }

  static Color _defaultColor(QuickAlertType type) {
    switch (type) {
      case QuickAlertType.success:
        return Colors.green;
      case QuickAlertType.error:
        return Colors.red;
      case QuickAlertType.warning:
        return Colors.orange;
      case QuickAlertType.info:
        return Colors.blueAccent;
      case QuickAlertType.confirm:
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }
}
