import 'dart:ui';
import 'package:flutter/material.dart';

class WidgetLibrary {
  static AlertDialog errorAlert({required String title, required String body}) {
    return AlertDialog(
      title: Text(title, softWrap: true, textAlign: TextAlign.center),
      content: Text(
        body,
        softWrap: true,
        textAlign: TextAlign.center,
      ),
    );
  }

  static void showAlert(BuildContext context, Widget dialog) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return dialog;
        });
  }
}
