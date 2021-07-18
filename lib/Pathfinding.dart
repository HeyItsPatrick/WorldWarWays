import "dart:ui";

class Node {
  String id = "";
  double x = 0;
  double y = 0;
  Map<String, double> connections = {};
  Offset get topLeft => Offset(this.x, this.y);
  Offset get center => Offset(this.x + 3, this.y + 3);
  bool get isEmpty => this.id.isEmpty;

  Node(this.id, this.x, this.y, this.connections);
  Node.empty();
  Node.fromNode(Node node) {
    this.id = node.id;
    this.x = node.x;
    this.y = node.y;
    this.connections = node.connections;
  }
}

void generateDistancesFWA(Map<String, Node> nodeGraph) {
  const largeValue = 1073741823 >> 1;
  final List<List> adjList = [];
  List<List> adjMatrix = [];
// convert entire node graph into matrix, where each coord position is either infinity or the weight between the nodes of that index
  var v = nodeGraph.keys.map((k) => double.parse(k.replaceAll("Node", ""))).toList();
  v.sort();
  int vertexCount = v.last.toInt() + 1;
  // Create a 2D array and populate it with a large value except at
  // i = j which is set equal to 0.
  adjMatrix = new List.generate(vertexCount, (i) => new List.generate(vertexCount, (j) => i == j ? 0 : largeValue));
  // empty mat for tracking pathing
  List<List> next = new List.generate(vertexCount, (i) => new List.generate(vertexCount, (j) => i == j ? 0 : largeValue));

  //adjList is format [[to,from,weight],...]
  nodeGraph.forEach((k, v) {
    v.connections.forEach((n, d) {
      adjList.add([double.parse(k.replaceAll("Node", "")), double.parse(n.replaceAll("Node", "")), d]);
    });
  });

  // Map the adjacency list to the sparse array.
  for (var i = 0; i < adjList.length; i++) {
    adjMatrix[adjList[i][0]][adjList[i][1]] = adjList[i][2];
  }
  for (int i = 0; i < vertexCount; i++) {
    for (int j = 0; j < vertexCount; j++) {
      if (adjMatrix[i][j] == largeValue) {
        next[j][i] = -1;
      } else {
        next[j][i] = j;
      }
    }
  }

  // Implement the Floyd Warshall dynamic programming algorithm.
  for (var k = 0; k < vertexCount; k++) {
    for (var i = 0; i < vertexCount; i++) {
      for (var j = 0; j < vertexCount; j++) {
        if (adjMatrix[i][j] > adjMatrix[i][k] + adjMatrix[k][j]) {
          adjMatrix[i][j] = adjMatrix[i][k] + adjMatrix[k][j];
          next[j][i] = next[k][i];
        }
      }
    }
  }
}

List<int> findShortestPathFWA(List<int> pathList, int start, int end) {
  if (pathList[end] == -1) {
    // print("no path from $start to $end");
    return [];
  } else {
    List<int> path = [end];
    var u = end;
    while (u != start) {
      u = pathList[u];
      path.add(u);
    }
    return path.reversed.toList();
  }
}
