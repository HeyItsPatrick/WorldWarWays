import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:world_war_waze/WidgetLibrary.dart';
import "dart:math";

import 'package:cloud_firestore/cloud_firestore.dart';

import "Pathfinding.dart";
import "RoutePainter.dart";
import "MapNodes/NodeImport.dart";
import "MapPaths/PathsImport.dart";

/* TERMINAL COMMANDS/STEPS FOR ACTIONS
-- Build for web
  flutter build web
  add `--web-renderer html` if the network images stop showing up
-- Publish to Surge.sh
  flutter build web
  surge
  Then set the directory to ./build/web in the prompt
  Publish to worldwarwaze.surge.sh
-- Publish to Firebase
  flutter build web
  firebase deploy
-- `firebase login` can access the CLI for firebase, without having to use the website all the time
-- REMINDER
  In order for Firebase to work, the ./web/index.html needs these lines:
    <script src="https://www.gstatic.com/firebasejs/8.6.1/firebase-app.js"></script>
    <script src="https://www.gstatic.com/firebasejs/8.6.1/firebase-firestore.js"></script>
    <!-- Firebase Configuration -->
    <script>
        const firebaseConfig = {
          apiKey: "AIzaSyDC6Vb436DRNglCSeaSQtbY9wx0_UN2Oc8",
          authDomain: "worldwarways.firebaseapp.com",
          projectId: "worldwarways",
          storageBucket: "worldwarways.appspot.com",
          messagingSenderId: "927538788359",
          appId: "1:927538788359:web:62c03a536bcb568b7152a2"
        };

      // Initialize Firebase
      firebase.initializeApp(firebaseConfig);
    </script>
*/

void main() => runApp(MyApp());

// theme: ThemeData.from(
//   colorScheme: ColorScheme(
//     primary: Color(0xff606c38),
//     primaryVariant: Color(0xff283618),
//     background: Colors.grey,
//     secondary: Color(0xffdda15e),
//     secondaryVariant: Color(0xffbc6c25),
//     error: Colors.red,
//     surface: Colors.purple, //BottomAppBar
//     brightness: Brightness.light,
//     onPrimary: Color(0xfffefae0),
//     onBackground: Colors.black,
//     onError: Colors.white,
//     onSecondary: Colors.black,
//     onSurface: Colors.black,
//   ),
// 606c38  283618   fefae0   dda15e   bc6c25
// https://material.io/resources/color/#!/?view.left=0&view.right=1&primary.color=51603f&secondary.color=dda15e&primary.text.color=ffffff

//https://medium.com/flutter-community/flutter-crud-operations-using-firebase-cloud-firestore-a7ef38bbf027
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "World War Ways",
      theme: ThemeData.from(
        colorScheme: ColorScheme(
          primary: Color(0xff606c38),
          primaryVariant: Color(0xff283618),
          background: Colors.grey.shade400,
          secondary: Color(0xffdda15e),
          secondaryVariant: Color(0xffbc6c25),
          error: Colors.red,
          surface: Color(0xfffefae0), //BottomAppBar
          brightness: Brightness.light,
          onPrimary: Color(0xfffefae0),
          onBackground: Colors.black,
          onError: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.black,
        ),
      ),
      home: MapViewer(),
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
    );
  }
}

class MapViewer extends StatefulWidget {
  MapViewer({Key? key}) : super(key: key);

  @override
  _MapViewerState createState() => _MapViewerState();
}

class _MapViewerState extends State<MapViewer> with WidgetsBindingObserver {
  // Nodes currently being loaded from file. Starts with Carentan.
  Map<String, Map<String, String>> nodesToLoad = carentanNodes;
  // Map of all the nodes; constructed from the loaded file
  Map<String, Node> nodeMap = {};
  // URL to the map image to show. Starts with Carentan.
  String mapUrl = carentanMapUrl;
  // Matrix [startIndex][endIndex] used to construct the paths from point to point
  List<List<int>> pathMatrix = carentanPaths;

  // Nodes nearest to start and end taps
  Node routeNodeStart = Node.empty();
  Node routeNodeEnd = Node.empty();
  // Nodes for waypoint pins
  List<Node> routeNodes = [];

  // Start and end tap positions in widget
  Offset routeTapStart = Offset.zero;
  Offset routeTapEnd = Offset.zero;
  // Current computed route to draw
  List<Node> computedRoute = [];

  String title = "World War Ways - Carentan";

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection("mapData").doc("mapVisits").update({"carentan": FieldValue.increment(1)}).then((value) {});
    loadNodesFromFile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 8.0,
          minScale: 0.25,
          constrained: false,
          child: GestureDetector(
            child: CustomPaint(
              child: Image.network(mapUrl),
              foregroundPainter: RoutePainter(nodeMap, routeNodes, routeTapStart, routeTapEnd, computedRoute),
            ),
            onTapUp: onTap,
            // Catch accidental double clicks, but also this is req'd for onDoubleTapDown. Not sure why.
            onDoubleTap: () {},
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.navigation_outlined),
        onPressed: () {
          if (routeNodes.isEmpty) {
            WidgetLibrary.showAlert(context, WidgetLibrary.errorAlert(title: "Route Error", body: "Route needs a start point."));
            return;
          } else if (routeNodes.length <= 1) {
            WidgetLibrary.showAlert(context, WidgetLibrary.errorAlert(title: "Route Error", body: "Route needs an end point."));
            return;
          }
          List<int> route = [];
          Node startNode = routeNodes.first;
          // skip the first node so we don't double up on accident
          for (Node endNode in routeNodes.skip(1)) {
            int start = int.parse(startNode.id.replaceAll("Node", ""));
            int end = int.parse(endNode.id.replaceAll("Node", ""));
            List<int> path = findShortestPathFWA(this.pathMatrix[start], start, end);
            if (path.isNotEmpty) {
              route.addAll(path);
            } else {
              // Move the ends for the path line drawing
              this.routeNodeEnd = routeNodes[routeNodes.indexOf(endNode) - 1];
              this.routeTapEnd = routeNodes[routeNodes.indexOf(endNode) - 1].center;
              // Remove nodes from routeNodes so any further waypoints aren't left on the map
              routeNodes.removeRange(routeNodes.indexOf(endNode), routeNodes.length);
              if (route.isNotEmpty) {
                WidgetLibrary.showAlert(context, WidgetLibrary.errorAlert(title: "Route Error", body: "No route beyond this point."));
              }
              break;
            }
            addRouteDataToFirestore(int.parse(startNode.id.replaceAll("Node", "")), int.parse(endNode.id.replaceAll("Node", "")));
            // Do this to stitch together waypoint to waypoint paths without doubling up at the overlap
            startNode = endNode;
          }
          List<Node> nodeRoute = [];
          // Translate the returned route of indices to Nodes
          for (int index in route) {
            String nodeID = "Node" + index.toString();
            if (this.nodeMap[nodeID] != null) {
              nodeRoute.add(this.nodeMap[nodeID]!);
            }
          }
          if (nodeRoute.isEmpty) {
            WidgetLibrary.showAlert(context, WidgetLibrary.errorAlert(title: "Route Error", body: "No route between those points."));
            clearRoute();
          }
          setState(() => this.computedRoute = nodeRoute);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        child: Row(
          children: [
            Spacer(),
            IconButton(
              icon: Icon(Icons.undo_outlined),
              onPressed: () {
                if (routeNodes.length > 2) {
                  setState(() {
                    routeNodes.removeLast();
                    routeTapEnd = routeNodes.last.center;
                    while (computedRoute.isNotEmpty && computedRoute.last != routeNodes.last) {
                      computedRoute.removeLast();
                    }
                  });
                } else if (routeNodes.length == 2) {
                  setState(() {
                    routeNodes.removeLast();
                    computedRoute = [];
                    routeTapEnd = Offset.zero;
                  });
                } else {
                  clearRoute();
                }
              },
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () => clearRoute(),
            ),
            Spacer(),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Center(
                child: Text(
                  "World War Ways",
                  textScaleFactor: 2,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 25),
              child: Text(
                "Maps",
                textAlign: TextAlign.left,
                textScaleFactor: 1.5,
              ),
            ),
            Divider(
              color: Colors.grey,
              height: 10,
              thickness: 2,
              indent: 0,
              endIndent: 0,
            ),
            mapSwitchButton("Carentan", carentanMapUrl, carentanNodes, carentanPaths),
            mapSwitchButton("Foy", foyMapUrl, foyNodes, foyPaths),
            mapSwitchButton("Hill 400", hill400MapUrl, hill400Nodes, hill400Paths),
            mapSwitchButton("Hurtgen Forest", hurtgenForestMapUrl, hurtgenForestNodes, hurtgenForestPaths),
            mapSwitchButton("Omaha Beach", omahaBeachMapUrl, omahaBeachNodes, omahaBeachPaths),
            mapSwitchButton("Purple Heart Lane", purpleHeartLaneMapUrl, purpleHeartLaneNodes, purpleHeartLanePaths),
            mapSwitchButton("Saint Mare Eglise", saintMareEgliseMapUrl, saintMareEgliseNodes, saintMareEglisePaths),
            mapSwitchButton("Saint Marie Du Mont", saintMarieDuMontMapUrl, saintMarieDuMontNodes, saintMarieDuMontPaths),
            mapSwitchButton("Utah Beach", utahBeachMapUrl, utahBeachNodes, utahBeachPaths),
            Divider(),
            mapSwitchButton("Kursk", kurskMapUrl, kurskNodes, kurskPaths),
            mapSwitchButton("Stalingrad", stalingradMapUrl, stalingradNodes, stalingradPaths),
          ],
        ),
      ),
    );
  }

  void onTap(TapUpDetails details) {
    // find nearest node
    Node nearestNode = nodeMap.values.first;
    double nearestDistance = double.infinity;
    nodeMap.forEach((node, data) {
      double dist = (data.center - details.localPosition).distance;
      if (dist < nearestDistance) {
        nearestDistance = dist;
        nearestNode = data;
      }
    });
    List<Node> nodeRoute = [];
    // If there's an active route, do live updates
    if (computedRoute.isNotEmpty) {
      int start = int.parse(routeNodes.last.id.replaceAll("Node", ""));
      int end = int.parse(nearestNode.id.replaceAll("Node", ""));
      // Translate the returned route of indices to Nodes
      for (int index in findShortestPathFWA(this.pathMatrix[start], start, end).skip(1)) {
        String nodeID = "Node" + index.toString();
        if (nodeMap[nodeID] != null) {
          nodeRoute.add(nodeMap[nodeID]!);
        }
      }
      if (nodeRoute.isEmpty) {
        WidgetLibrary.showAlert(context, WidgetLibrary.errorAlert(title: "Route Error", body: "No route between those points."));
        return;
      }
      addRouteDataToFirestore(start, end);
    }
    setState(() {
      routeNodes.add(nearestNode);
      if (routeTapStart == Offset.zero) {
        // No point in showing 2 pins if they are practically right on top of each other. It just clutters the screen
        routeTapStart = (details.localPosition - nearestNode.center).distance < 10 ? nearestNode.center : details.localPosition;
      } else {
        routeTapEnd = (details.localPosition - nearestNode.center).distance < 10 ? nearestNode.center : details.localPosition;
      }
      computedRoute.addAll(nodeRoute);
    });
  }

  void clearRoute() {
    setState(() {
      this.routeNodeStart = Node.empty();
      this.routeNodeEnd = Node.empty();
      this.routeTapStart = Offset.zero;
      this.routeTapEnd = Offset.zero;
      this.computedRoute = [];
      this.routeNodes = [];
    });
  }

  ListTile mapSwitchButton(String mapName, String mapUrl, Map<String, Map<String, String>> mapNodes, List<List<int>> pathMatrix) {
    return ListTile(
      contentPadding: EdgeInsets.fromLTRB(50, 4, 0, 4),
      title: Text(mapName),
      onTap: () {
        FirebaseFirestore.instance
            .collection("mapData")
            .doc("mapVisits")
            .update({"${mapName[0].toLowerCase()}${mapName.substring(1).replaceAll(' ', '')}": FieldValue.increment(1)}).then((value) {});
        Navigator.pop(context);
        clearRoute();
        setState(() {
          title = "World War Ways - " + mapName;
          this.mapUrl = mapUrl;
          nodesToLoad = mapNodes;
          this.pathMatrix = pathMatrix;
        });
        loadNodesFromFile();
      },
    );
  }

  void addRouteDataToFirestore(int start, int end) {
    String mapName = this.title.replaceAll("World War Ways - ", "").replaceAll(' ', '');
    mapName = "${mapName[0].toLowerCase()}${mapName.substring(1)}RouteCount";
    FirebaseFirestore.instance.collection("mapData").doc(mapName).update({"$start->$end": FieldValue.increment(1)});
  }

  void loadNodesFromFile() {
    // Construct Node List from file
    Map<String, Node> newNodeMap = {};
    this.nodesToLoad.forEach((node, data) {
      Map<String, double> connections = {};
      double nodePtX = double.parse(data["x"] ?? "0") - 8; // To account for the margin offset from the web page
      double nodePtY = double.parse(data["y"] ?? "0") - 8; // This offset will have to stay until data is redone
      for (String nextNode in data["nodes"]?.split(",") ?? []) {
        nextNode = nextNode.trim();
        if (nextNode.length != 0) {
          double nextNodePtX = double.parse(nodesToLoad[nextNode]?["x"] ?? "0") - 8;
          double nextNodePtY = double.parse(nodesToLoad[nextNode]?["y"] ?? "0") - 8;
          double dist = sqrt(pow(nextNodePtX - nodePtX, 2) + pow(nextNodePtY - nodePtY, 2));
          connections[nextNode] = dist;
        }
      }
      newNodeMap[node] = Node(node, nodePtX, nodePtY, connections);
    });
    setState(() => this.nodeMap = newNodeMap);
  }
}
