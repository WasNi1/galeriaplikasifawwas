import 'package:flutter/cupertino.dart';

class SyncScrollController extends ScrollController {
  final ScrollController parentController;
  bool _isScrollingParent = false;

  SyncScrollController({required this.parentController}) {
    addListener(_syncWithParent);
    parentController.addListener(_handleParentScroll);
  }

  void _syncWithParent() {
    if (!_isScrollingParent && hasClients) {
      _isScrollingParent = true;
      parentController.jumpTo(offset);
      _isScrollingParent = false;
    }
  }

  void _handleParentScroll() {
    if (hasClients && offset != parentController.offset) {
      jumpTo(parentController.offset);
    }
  }

  @override
  void dispose() {
    removeListener(_syncWithParent);
    parentController.removeListener(_handleParentScroll);
    super.dispose();
  }
}