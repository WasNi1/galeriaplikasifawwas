import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomScrollableTabView extends StatefulWidget {
  final TabController tabController;
  final List<Widget> children;
  final Widget header;
  final double headerHeight;
  final double collapsedHeight;
  final bool pinned;

  const CustomScrollableTabView({
   Key? key,
   required this.tabController,
   required this.children,
   required this.header,
   this.headerHeight = 355,
   this.collapsedHeight = 60.0,
   this.pinned = true,
}) : super(key: key);

  @override
  State<CustomScrollableTabView> createState() => _CustomScrollableTabViewState();
}

class _CustomScrollableTabViewState extends State<CustomScrollableTabView> {
  final PageController _pageController = PageController();
  final List<ScrollController> _scrollControllers = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < widget.children.length; i++) {
      _scrollControllers.add(ScrollController());
    }

    widget.tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (widget.tabController.indexIsChanging) {
      _pageController.animateToPage(
          widget.tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {

        }
        return false;
      }, child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: widget.headerHeight,
            collapsedHeight: widget.collapsedHeight,
            pinned: widget.pinned,
            flexibleSpace: widget.header,
          ),
          SliverFillRemaining(
            child: PageView.builder(
              controller: _pageController,
                onPageChanged: (index) {
                  if (widget.tabController.index != index) {
                    widget.tabController.animateTo(index);
                  }
                },
                itemCount: widget.children.length,
                itemBuilder: (context, index) {
                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      return false;
                    },
                      child: SingleChildScrollView(
                        controller: _scrollControllers[index],
                        child: widget.children[index],
                      ),
                  );
                }
            ),
          )
        ],
      ),
    );
  }
}