class ExpandableCardController {
  Future<bool> Function()? _collapseRequest;

  Future<bool> requestCollapse() =>
      _collapseRequest?.call() ?? Future<bool>.value(true);

  void attach(Future<bool> Function() collapseRequest) {
    _collapseRequest = collapseRequest;
  }

  void detach(Future<bool> Function() collapseRequest) {
    if (_collapseRequest == collapseRequest) _collapseRequest = null;
  }
}
