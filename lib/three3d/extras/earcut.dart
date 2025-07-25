import 'package:three_dart_flutterflow/three3d/math/index.dart';

/// Port from https://github.com/mapbox/earcut (v2.2.2)

class Earcut {
  static triangulate(data, List<num>? holeIndices, dim) {
    dim = dim ?? 2;

    var hasHoles = holeIndices != null && holeIndices.isNotEmpty;
    var outerLen = hasHoles ? holeIndices![0] * dim : data.length;

    var outerNode = linkedList(data, 0, outerLen, dim, true);
    var triangles = [];

    if (outerNode == null || outerNode.next == outerNode.prev) return triangles;

    var minX, minY, maxX, maxY, x, y, invSize;

    if (hasHoles) outerNode = eliminateHoles(data, holeIndices, outerNode, dim);

    // if the shape is not too simple, we'll use z-order curve hash later; calculate polygon bbox
    if (data.length > 80 * dim) {
      minX = maxX = data[0];
      minY = maxY = data[1];

      for (var i = dim; i < outerLen; i += dim) {
        x = data[i];
        y = data[i + 1];
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }

      // minX, minY and invSize are later used to transform coords into integers for z-order calculation
      invSize = Math.max<num>(maxX - minX, maxY - minY);
      invSize = invSize != 0 ? 1 / invSize : 0;
    }

    earcutLinked(outerNode, triangles, dim, minX, minY, invSize, null);

    return triangles;
  }
}

// create a circular doubly linked list from polygon points in the specified winding order
linkedList(data, start, end, dim, clockwise) {
  var i, last;

  if (clockwise == (signedArea(data, start, end, dim) > 0)) {
    for (i = start; i < end; i += dim) {
      last = insertNode(i, data[i], data[i + 1], last);
    }
  } else {
    for (i = end - dim; i >= start; i -= dim) {
      last = insertNode(i, data[i], data[i + 1], last);
    }
  }

  if (last != null && equals(last, last.next)) {
    removeNode(last);
    last = last.next;
  }

  return last;
}

// eliminate colinear or duplicate points
filterPoints(start, end) {
  if (start == null) return start;
  end ??= start;

  var p = start, again;
  do {
    again = false;

    if (!p.steiner && (equals(p, p.next) || area(p.prev, p, p.next) == 0)) {
      removeNode(p);
      p = end = p.prev;
      if (p == p.next) break;
      again = true;
    } else {
      p = p.next;
    }
  } while (again || p != end);

  return end;
}

// main ear slicing loop which triangulates a polygon (given as a linked list)
earcutLinked(Node? ear, triangles, dim, minX, minY, num? invSize, num? pass) {
  if (ear == null) return;

  // interlink polygon nodes in z-order
  if (pass == null && invSize != null) indexCurve(ear, minX, minY, invSize);

  var stop = ear, prev, next;

  // iterate through ears, slicing them one by one
  while (ear!.prev != ear.next) {
    prev = ear.prev;
    next = ear.next;

    if (invSize != null ? isEarHashed(ear, minX, minY, invSize) : isEar(ear)) {
      // cut off the triangle
      triangles.add(prev.i / dim);
      triangles.add(ear.i / dim);
      triangles.add(next.i / dim);

      removeNode(ear);

      // skipping the next vertex leads to less sliver triangles
      ear = next.next;
      stop = next.next;

      continue;
    }

    ear = next;

    // if we looped through the whole remaining polygon and can't find any more ears
    if (ear == stop) {
      // try filtering points and slicing again
      if (pass == null || pass == 0) {
        earcutLinked(filterPoints(ear, null), triangles, dim, minX, minY, invSize, 1);

        // if this didn't work, try curing all small self-intersections locally

      } else if (pass == 1) {
        ear = cureLocalIntersections(filterPoints(ear, null), triangles, dim);
        earcutLinked(ear, triangles, dim, minX, minY, invSize, 2);

        // as a last resort, try splitting the remaining polygon into two

      } else if (pass == 2) {
        splitEarcut(ear, triangles, dim, minX, minY, invSize);
      }

      break;
    }
  }
}

// check whether a polygon node forms a valid ear with adjacent nodes
isEar(ear) {
  var a = ear.prev, b = ear, c = ear.next;

  if (area(a, b, c) >= 0) return false; // reflex, can't be an ear

  // now make sure we don't have other points inside the potential ear
  var p = ear.next.next;

  while (p != ear.prev) {
    if (pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) && area(p.prev, p, p.next) >= 0) return false;
    p = p.next;
  }

  return true;
}

isEarHashed(ear, minX, minY, invSize) {
  var a = ear.prev, b = ear, c = ear.next;

  if (area(a, b, c) >= 0) return false; // reflex, can't be an ear

  // triangle bbox; min & max are calculated like this for speed
  var minTX = a.x < b.x ? (a.x < c.x ? a.x : c.x) : (b.x < c.x ? b.x : c.x),
      minTY = a.y < b.y ? (a.y < c.y ? a.y : c.y) : (b.y < c.y ? b.y : c.y),
      maxTX = a.x > b.x ? (a.x > c.x ? a.x : c.x) : (b.x > c.x ? b.x : c.x),
      maxTY = a.y > b.y ? (a.y > c.y ? a.y : c.y) : (b.y > c.y ? b.y : c.y);

  // z-order range for the current triangle bbox;
  var minZ = zOrder(minTX, minTY, minX, minY, invSize), maxZ = zOrder(maxTX, maxTY, minX, minY, invSize);

  var p = ear.prevZ, n = ear.nextZ;

  // look for points inside the triangle in both directions
  while (p != null && p.z >= minZ && n != null && n.z <= maxZ) {
    if (p != ear.prev &&
        p != ear.next &&
        pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) &&
        area(p.prev, p, p.next) >= 0) return false;
    p = p.prevZ;

    if (n != ear.prev &&
        n != ear.next &&
        pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, n.x, n.y) &&
        area(n.prev, n, n.next) >= 0) return false;
    n = n.nextZ;
  }

  // look for remaining points in decreasing z-order
  while (p != null && p.z >= minZ) {
    if (p != ear.prev &&
        p != ear.next &&
        pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) &&
        area(p.prev, p, p.next) >= 0) return false;
    p = p.prevZ;
  }

  // look for remaining points in increasing z-order
  while (n != null && n.z <= maxZ) {
    if (n != ear.prev &&
        n != ear.next &&
        pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, n.x, n.y) &&
        area(n.prev, n, n.next) >= 0) return false;
    n = n.nextZ;
  }

  return true;
}

// go through all polygon nodes and cure small local self-intersections
cureLocalIntersections(start, triangles, dim) {
  var p = start;
  do {
    var a = p.prev, b = p.next.next;

    if (!equals(a, b) && intersects(a, p, p.next, b) && locallyInside(a, b) && locallyInside(b, a)) {
      triangles.add(a.i / dim);
      triangles.add(p.i / dim);
      triangles.add(b.i / dim);

      // remove two nodes involved
      removeNode(p);
      removeNode(p.next);

      p = start = b;
    }

    p = p.next;
  } while (p != start);

  return filterPoints(p, null);
}

// try splitting polygon into two and triangulate them independently
splitEarcut(start, triangles, dim, minX, minY, invSize) {
  // look for a valid diagonal that divides the polygon into two
  var a = start;
  do {
    var b = a.next.next;
    while (b != a.prev) {
      if (a.i != b.i && isValidDiagonal(a, b)) {
        // split the polygon in two by the diagonal
        var c = splitPolygon(a, b);

        // filter colinear points around the cuts
        a = filterPoints(a, a.next);
        c = filterPoints(c, c.next);

        // run earcut on each half
        earcutLinked(a, triangles, dim, minX, minY, invSize, null);
        earcutLinked(c, triangles, dim, minX, minY, invSize, null);
        return;
      }

      b = b.next;
    }

    a = a.next;
  } while (a != start);
}

// link every hole into the outer loop, producing a single-ring polygon without holes
eliminateHoles(data, holeIndices, outerNode, dim) {
  var queue = [];
  var start, end, list;

  for (var i = 0, len = holeIndices.length; i < len; i++) {
    start = holeIndices[i] * dim;
    end = i < len - 1 ? holeIndices[i + 1] * dim : data.length;
    list = linkedList(data, start, end, dim, false);
    if (list == list.next) list.steiner = true;
    queue.add(getLeftmost(list));
  }

  queue.sort((a, b) => compareX(a, b));

  // process holes from left to right
  for (var i = 0; i < queue.length; i++) {
    eliminateHole(queue[i], outerNode);
    outerNode = filterPoints(outerNode, outerNode.next);
  }

  return outerNode;
}

int compareX(a, b) {
  if (a.x == b.x) {
    return 0;
  } else if (a.x > b.x) {
    return 1;
  } else {
    return -1;
  }
  // return a.x - b.x;
}

// find a bridge between vertices that connects hole with an outer ring and and link it
eliminateHole(hole, outerNode) {
  outerNode = findHoleBridge(hole, outerNode);
  if (outerNode != null) {
    var b = splitPolygon(outerNode, hole);

    // filter collinear points around the cuts
    filterPoints(outerNode, outerNode.next);
    filterPoints(b, b.next);
  }
}

// David Eberly's algorithm for finding a bridge between hole and outer polygon
findHoleBridge(hole, outerNode) {
  var p = outerNode;
  var hx = hole.x;
  var hy = hole.y;
  var qx = -Math.infinity, m;

  // find a segment intersected by a ray from the hole's leftmost point to the left;
  // segment's endpoint with lesser x will be potential connection point
  do {
    if (hy <= p.y && hy >= p.next.y && p.next.y != p.y) {
      var x = p.x + (hy - p.y) * (p.next.x - p.x) / (p.next.y - p.y);
      if (x <= hx && x > qx) {
        qx = x;
        if (x == hx) {
          if (hy == p.y) return p;
          if (hy == p.next.y) return p.next;
        }

        m = p.x < p.next.x ? p : p.next;
      }
    }

    p = p.next;
  } while (p != outerNode);

  if (m == null) return null;

  if (hx == qx) return m; // hole touches outer segment; pick leftmost endpoint

  // look for points inside the triangle of hole point, segment intersection and endpoint;
  // if there are no points found, we have a valid connection;
  // otherwise choose the point of the minimum angle with the ray as connection point

  var stop = m, mx = m.x, my = m.y;
  var tanMin = Math.infinity, tan;

  p = m;

  do {
    if (hx >= p.x &&
        p.x >= mx &&
        hx != p.x &&
        pointInTriangle(hy < my ? hx : qx, hy, mx, my, hy < my ? qx : hx, hy, p.x, p.y)) {
      tan = Math.abs(hy - p.y) / (hx - p.x); // tangential

      if (locallyInside(p, hole) &&
          (tan < tanMin || (tan == tanMin && (p.x > m.x || (p.x == m.x && sectorContainsSector(m, p)))))) {
        m = p;
        tanMin = tan;
      }
    }

    p = p.next;
  } while (p != stop);

  return m;
}

// whether sector in vertex m contains sector in vertex p in the same coordinates
sectorContainsSector(m, p) {
  return area(m.prev, m, p.prev) < 0 && area(p.next, m, m.next) < 0;
}

// interlink polygon nodes in z-order
indexCurve(Node start, minX, minY, invSize) {
  var p = start;
  do {
    p.z ??= zOrder(p.x, p.y, minX, minY, invSize);
    p.prevZ = p.prev;
    p.nextZ = p.next;
    p = p.next!;
  } while (p != start);

  p.prevZ!.nextZ = null;
  p.prevZ = null;

  sortLinked(p);
}

// Simon Tatham's linked list merge sort algorithm
// http://www.chiark.greenend.org.uk/~sgtatham/algorithms/listsort.html
sortLinked(list) {
  var i, p, q, e, tail, numMerges, pSize, qSize, inSize = 1;

  do {
    p = list;
    list = null;
    tail = null;
    numMerges = 0;

    while (p != null) {
      numMerges++;
      q = p;
      pSize = 0;
      for (i = 0; i < inSize; i++) {
        pSize++;
        q = q.nextZ;
        if (q == null) break;
      }

      qSize = inSize;

      while (pSize > 0 || (qSize > 0 && q != null)) {
        if (pSize != 0 && (qSize == 0 || q == null || p.z <= q.z)) {
          e = p;
          p = p.nextZ;
          pSize--;
        } else {
          e = q;
          q = q.nextZ;
          qSize--;
        }

        if (tail != null) {
          tail.nextZ = e;
        } else {
          list = e;
        }

        e.prevZ = tail;
        tail = e;
      }

      p = q;
    }

    tail.nextZ = null;
    inSize *= 2;
  } while (numMerges > 1);

  return list;
}

// << 等运算 在web环境下浮点类型可以计算 在移动端app上会报错 需要先转为int
// z-order of a point given coords and inverse of the longer side of data bbox
zOrder(num x0, num y0, num minX, num minY, num invSize) {
  // coords are transformed into non-negative 15-bit integer range
  int x = (32767 * (x0 - minX) * invSize).floor().toInt();
  int y = (32767 * (y0 - minY) * invSize).floor().toInt();

  x = (x | (x << 8)) & 0x00FF00FF;
  x = (x | (x << 4)) & 0x0F0F0F0F;
  x = (x | (x << 2)) & 0x33333333;
  x = (x | (x << 1)) & 0x55555555;

  y = (y | (y << 8)) & 0x00FF00FF;
  y = (y | (y << 4)) & 0x0F0F0F0F;
  y = (y | (y << 2)) & 0x33333333;
  y = (y | (y << 1)) & 0x55555555;

  return x | (y << 1);
}

// find the leftmost node of a polygon ring
getLeftmost(start) {
  var p = start, leftmost = start;
  do {
    if (p.x < leftmost.x || (p.x == leftmost.x && p.y < leftmost.y)) {
      leftmost = p;
    }
    p = p.next;
  } while (p != start);

  return leftmost;
}

// check if a point lies within a convex triangle
pointInTriangle(ax, ay, bx, by, cx, cy, px, py) {
  return (cx - px) * (ay - py) - (ax - px) * (cy - py) >= 0 &&
      (ax - px) * (by - py) - (bx - px) * (ay - py) >= 0 &&
      (bx - px) * (cy - py) - (cx - px) * (by - py) >= 0;
}

// check if a diagonal between two polygon nodes is valid (lies in polygon interior)
isValidDiagonal(a, b) {
  var b1 = a.next.i != b.i;
  var b2 = a.prev.i != b.i;
  var b3 = !intersectsPolygon(a, b);

  var b41 = locallyInside(a, b);
  var b42 = locallyInside(b, a);
  var b43 = middleInside(a, b);

  // does not create opposite-facing sectors
  var b44 = area(a.prev, a, b.prev) != 0;
  var b45 = area(a, b.prev, b) != 0;

  var b46 = equals(a, b);
  var b47 = area(a.prev, a, a.next) > 0;
  var b48 = area(b.prev, b, b.next) > 0;
  // locally visible

  var b4 = (b41 && b42 && b43 && (b44 || b45) || b46 && b47 && b48);

  // dones't intersect other edges
  return b1 && b2 && b3 && b4; // special zero-length case
}

// signed area of a triangle
area(p, q, r) {
  return (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
}

// check if two points are equal
equals(p1, p2) {
  return p1.x == p2.x && p1.y == p2.y;
}

// check if two segments intersect
intersects(p1, q1, p2, q2) {
  var o1 = sign(area(p1, q1, p2));
  var o2 = sign(area(p1, q1, q2));
  var o3 = sign(area(p2, q2, p1));
  var o4 = sign(area(p2, q2, q1));

  if (o1 != o2 && o3 != o4) return true; // general case

  if (o1 == 0 && onSegment(p1, p2, q1)) {
    return true;
  } // p1, q1 and p2 are collinear and p2 lies on p1q1
  if (o2 == 0 && onSegment(p1, q2, q1)) {
    return true;
  } // p1, q1 and q2 are collinear and q2 lies on p1q1
  if (o3 == 0 && onSegment(p2, p1, q2)) {
    return true;
  } // p2, q2 and p1 are collinear and p1 lies on p2q2
  if (o4 == 0 && onSegment(p2, q1, q2)) {
    return true;
  } // p2, q2 and q1 are collinear and q1 lies on p2q2

  return false;
}

// for collinear points p, q, r, check if point q lies on segment pr
onSegment(p, q, r) {
  return q.x <= Math.max<num>(p.x, r.x) &&
      q.x >= Math.min<num>(p.x, r.x) &&
      q.y <= Math.max<num>(p.y, r.y) &&
      q.y >= Math.min<num>(p.y, r.y);
}

int sign(num num) {
  return num > 0
      ? 1
      : num < 0
          ? -1
          : 0;
}

// check if a polygon diagonal intersects any polygon segments
intersectsPolygon(a, b) {
  var p = a;
  do {
    if (p.i != a.i && p.next.i != a.i && p.i != b.i && p.next.i != b.i && intersects(p, p.next, a, b)) return true;
    p = p.next;
  } while (p != a);

  return false;
}

// check if a polygon diagonal is locally inside the polygon
locallyInside(a, b) {
  return area(a.prev, a, a.next) < 0
      ? area(a, b, a.next) >= 0 && area(a, a.prev, b) >= 0
      : area(a, b, a.prev) < 0 || area(a, a.next, b) < 0;
}

// check if the middle point of a polygon diagonal is inside the polygon
middleInside(a, b) {
  var p = a;
  bool inside = false;
  var px = (a.x + b.x) / 2, py = (a.y + b.y) / 2;
  do {
    if (((p.y > py) != (p.next.y > py)) &&
        p.next.y != p.y &&
        (px < (p.next.x - p.x) * (py - p.y) / (p.next.y - p.y) + p.x)) {
      inside = !inside;
    }
    p = p.next;
  } while (p != a);

  return inside;
}

// link two polygon vertices with a bridge; if the vertices belong to the same ring, it splits polygon into two;
// if one belongs to the outer ring and another to a hole, it merges it into a single ring
splitPolygon(a, b) {
  var a2 = Node(a.i, a.x, a.y), b2 = Node(b.i, b.x, b.y), an = a.next, bp = b.prev;

  a.next = b;
  b.prev = a;

  a2.next = an;
  an.prev = a2;

  b2.next = a2;
  a2.prev = b2;

  bp.next = b2;
  b2.prev = bp;

  return b2;
}

// create a node and optionally link it with previous one (in a circular doubly linked list)
insertNode(i, x, y, last) {
  var p = Node(i, x, y);

  if (last == null) {
    p.prev = p;
    p.next = p;
  } else {
    p.next = last.next;
    p.prev = last;
    last.next.prev = p;
    last.next = p;
  }

  return p;
}

removeNode(p) {
  p.next.prev = p.prev;
  p.prev.next = p.next;

  if (p.prevZ != null) p.prevZ.nextZ = p.nextZ;
  if (p.nextZ != null) p.nextZ.prevZ = p.prevZ;
}

class Node {
  num i;
  num x;
  num y;
  late Node? prev;
  late Node? next;
  late num? z;
  late Node? prevZ;
  late Node? nextZ;
  late bool steiner;

  Node(this.i, this.x, this.y) {
    // previous and next vertex nodes in a polygon ring
    prev = null;
    next = null;

    // z-order curve value
    z = null;

    // previous and next nodes in z-order
    prevZ = null;
    nextZ = null;

    // indicates whether this is a steiner point
    steiner = false;
  }
}

signedArea(data, start, end, dim) {
  var sum = 0.0;
  for (var i = start, j = end - dim; i < end; i += dim) {
    sum += (data[j] - data[i]) * (data[i + 1] + data[j + 1]);
    j = i;
  }

  return sum;
}
