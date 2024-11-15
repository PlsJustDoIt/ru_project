class CafeteriaTable {
  final int id;
  final double xPercent; // Position as percentage of container width
  final double yPercent; // Position as percentage of container height
  bool isOccupied;
  //Shape shape;

  CafeteriaTable({
    required this.id,
    required this.xPercent,
    required this.yPercent,
    //this.shape = const Shape(),  //TODO define shape of table
    this.isOccupied = false,
  });
}

class Shape { //TODO enum
  //rectangle, circle
}