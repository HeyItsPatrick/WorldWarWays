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
    /*  InteractiveViewer must have constrained=false in order for the nodes to be positioned properly
        This appears to be because, while the IV will scale the child widget to fit the window on init,
          it never adjusts its own coordinate system to reflect that rescaling.
        So the child image will do what I want, but the nodes will be placed as if the image is full size
        Unless I do some serious gymnastics to pass in the dimensions of the image and somehow determine the initial scaling,
          I can't really do much about this. Even then, I'm concerned that the math would introduce imprecision in node position
          because of decimal precision.

        Ideally, I want the entire width of the map visible on the screen when they start, if possible (ie on pc)
        I want the initial map load to centered within the screen, and zooming out beyond the edges of the map should also center it.
        I might be able to do this with either a subclassing of InteractiveViewer, and/or using the IV interaction functions,
          which miiiight let me also let me keep the coordinate system afforeded by constrained=false too.
        Just setting the boundary margin does the centering when zooming out, however I'm limited by screen size (image minScale is of the image
          original size, not the frame, so small frames can't zoom out enough to show the whole image) and it doesn't redraw the image when the
          window size changes (so going from a small to large window leaves extra padding on the right side and is fixed when I scroll).
        Constrained=true does basically everything I want, except it fucks the node positions hardcore.
    */

    // this.nodeMap.forEach((node, data) {
    //   canvas.drawRect(Rect.fromLTWH(data.x, data.y, 7, 7), Paint()..color = Colors.red);
    //   data.connections.forEach((id, dist) {
    //     canvas.drawLine(
    //         data.center,
    //         nodeMap[id]!.center,
    //         Paint()
    //           ..color = Colors.black
    //           ..strokeWidth = 5
    //           ..style = PaintingStyle.stroke);
    //   });
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
            ..strokeWidth = 5
            ..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
