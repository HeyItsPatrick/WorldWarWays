import "dart:ui";
import "package:flutter/material.dart";
import "Pathfinding.dart";

class RoutePainter extends CustomPainter {
  Map<String, Node> nodeMap;
  List<Node> currentRoute;
  Offset routeTapStart;
  Offset routeTapEnd;
  List<Node> routeNodes;

  final TextSpan greenPinSpan = TextSpan(
    text: String.fromCharCode(Icons.pin_drop_sharp.codePoint),
    style: TextStyle(
      fontSize: 50.0,
      fontFamily: Icons.pin_drop.fontFamily,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.greenAccent[700]!
        ..strokeWidth = 6,
    ),
  );
  final TextSpan redPinSpan = TextSpan(
    text: String.fromCharCode(Icons.pin_drop_sharp.codePoint),
    style: TextStyle(
      fontSize: 50.0,
      fontFamily: Icons.pin_drop.fontFamily,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.red
        ..strokeWidth = 6,
    ),
  );
  final TextSpan pinOutlineSpan = TextSpan(
    text: String.fromCharCode(Icons.pin_drop_outlined.codePoint),
    style: TextStyle(
      fontSize: 50.0,
      fontFamily: Icons.pin_drop.fontFamily,
      color: Colors.black,
    ),
  );

  final TextPainter textPainter = TextPainter(textDirection: TextDirection.rtl);

  RoutePainter(this.nodeMap, this.routeNodes, this.routeTapStart, this.routeTapEnd, this.currentRoute);
  @override
  void paint(Canvas canvas, Size size) {
    // this.nodeMap.forEach((node, data) {
    //   canvas.drawRect(Rect.fromLTWH(data.x, data.y, 7, 7), Paint()..color = Colors.red);
    //   // data.connections.forEach((id, dist) {
    //   //   canvas.drawLine(
    //   //       data.center,
    //   //       nodeMap[id]!.center,
    //   //       Paint()
    //   //         ..color = Colors.black
    //   //         ..strokeWidth = 5
    //   //         ..style = PaintingStyle.stroke);
    //   // });
    // });
    if (this.routeTapStart != Offset.zero) {
      // Draw Start Node
      textPainter.text = greenPinSpan;
      textPainter.layout();
      textPainter.paint(canvas, Offset(routeTapStart.dx - textPainter.width / 2, routeTapStart.dy - textPainter.height + 5));

      textPainter.text = pinOutlineSpan;
      textPainter.layout();
      textPainter.paint(canvas, Offset(routeTapStart.dx - textPainter.width / 2, routeTapStart.dy - textPainter.height + 5));
    }
    for (Node node in routeNodes) {
      // Draw middle nodes
      textPainter.text = pinOutlineSpan;
      textPainter.layout();
      textPainter.paint(canvas, Offset(node.center.dx - textPainter.width / 2, node.center.dy - textPainter.height + 5));
    }
    if (this.routeTapEnd != Offset.zero) {
      // Draw End Node
      textPainter.text = redPinSpan;
      textPainter.layout();
      textPainter.paint(canvas, Offset(routeTapEnd.dx - textPainter.width / 2, routeTapEnd.dy - textPainter.height + 5));

      textPainter.text = pinOutlineSpan;
      textPainter.layout();
      textPainter.paint(canvas, Offset(routeTapEnd.dx - textPainter.width / 2, routeTapEnd.dy - textPainter.height + 5));
    }
    if (currentRoute.isNotEmpty) {
      // Draw route lines
      List<Offset> routePts = currentRoute.map((node) => node.center).toList();
      routePts.insert(0, routeTapStart);
      routePts.add(routeTapEnd);
      canvas.drawPoints(
          PointMode.polygon,
          routePts,
          Paint()
            ..strokeWidth = 3
            ..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
