import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:world_war_waze/WidgetLibrary.dart';
import "dart:math";

import "Pathfinding.dart";
import "RoutePainter.dart";
import "MapNodes/NodeImport.dart";
import "MapPaths/PathsImport.dart";

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "World War Waze",
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapViewer(),
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

  String title = "World War Waze - Carentan";

  @override
  void initState() {
    super.initState();
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
          child: GestureDetector(
            child: CustomPaint(
              child: Image.network(mapUrl),
              foregroundPainter: RoutePainter(nodeMap, routeNodes, routeTapStart, routeTapEnd, computedRoute),
            ),
            onTapUp: (details) {
              // find nearest node
              Node nearestNode = nodeMap.values.first;
              double nearestDistance = 1000;
              nodeMap.forEach((node, data) {
                double dist = (data.center - details.localPosition).distance;
                if (dist < nearestDistance) {
                  nearestDistance = dist;
                  nearestNode = data;
                }
              });
              List<Node> nodeRoute = [];
              if (computedRoute.isNotEmpty) {
                int start = int.parse(routeNodes.last.id.replaceAll("Node", ""));
                int end = int.parse(nearestNode.id.replaceAll("Node", ""));
                // Translate the returned route of indices to Nodes
                for (int index in findShortestPathFWA(this.pathMatrix[start], start, end)) {
                  String nodeID = "Node" + index.toString();
                  if (nodeMap[nodeID] != null) {
                    nodeRoute.add(nodeMap[nodeID]!);
                  }
                }
                if (nodeRoute.isEmpty) {
                  WidgetLibrary.showAlert(context, WidgetLibrary.errorAlert(title: "Route Error", body: "No route between those points."));
                } else {}
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
            },
            // Catch accidental double clicks, but also this is req'd for onDoubleTapDown. Not sure why.
            onDoubleTap: () {},
          ),
          constrained: false,
          minScale: 0.01,
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
          for (Node endNode in routeNodes.getRange(1, routeNodes.length).toList()) {
            int start = int.parse(startNode.id.replaceAll("Node", ""));
            int end = int.parse(endNode.id.replaceAll("Node", ""));
            route.addAll(findShortestPathFWA(this.pathMatrix[start], start, end));
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
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
              child: Text("World War Waze"),
            ),
            Text("Maps"),
            Divider(),
            mapSwitchButton("Carentan", carentanMapUrl, carentanNodes, carentanPaths),
            mapSwitchButton("Foy", foyMapUrl, foyNodes, foyPaths),
            mapSwitchButton("Hill 400", hill400MapUrl, hill400Nodes, hill400Paths),
            mapSwitchButton("Hurtgen Forest", hurtgenForestMapUrl, hurtgenForestNodes, hurtgenForestPaths),
            mapSwitchButton("Omaha Beach", omahaBeachMapUrl, omahaBeachNodes, omahaBeachPaths),
            mapSwitchButton("Purple Heart Lane", purpleHeartLaneMapUrl, purpleHeartLaneNodes, purpleHeartLanePaths),
            mapSwitchButton("Saint Mare Eglise", saintMareEgliseMapUrl, saintMareEgliseNodes, saintMareEglisePaths),
            mapSwitchButton("Saint Marie Du Mont", saintMarieDuMontMapUrl, saintMarieDuMontNodes, saintMarieDuMontPaths),
            mapSwitchButton("Utah Beach", utahBeachMapUrl, utahBeachNodes, utahBeachPaths),
          ],
        ),
      ),
    );
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
      title: Text(mapName),
      onTap: () {
        Navigator.pop(context);
        clearRoute();
        setState(() {
          title = "World War Waze - " + mapName;
          this.mapUrl = mapUrl;
          nodesToLoad = mapNodes;
          this.pathMatrix = pathMatrix;
        });
        loadNodesFromFile();
      },
    );
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
