import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:story_time/story_page_view/story_limit_controller.dart';
import 'package:story_time/story_page_view/story_stack_controller.dart';

import 'components/gestures.dart';
import 'components/indicators.dart';

typedef StoryItemBuilder = Widget Function(
    BuildContext context, int pageIndex, int storyIndex);

typedef StoryConfigFunction = int Function(int pageIndex);

/// PageView to implement story like UI
///
/// [itemBuilder], [storyLength], [pageLength] are required.
class StoryPageView extends StatefulWidget {
  const StoryPageView({
    Key? key,
    required this.itemBuilder,
    required this.storyLength,
    required this.pageLength,
    this.gestureItemBuilder,
    this.initialStoryIndex,
    this.initialPage = 0,
    this.onPageLimitReached,
    this.indicatorDuration = const Duration(seconds: 5),
    this.indicatorPadding =
        const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
    this.backgroundColor = Colors.black,
    this.indicatorAnimationController,
    this.onStoryPaused,
    this.onStoryUnpaused,
    this.onPageBack,
    this.onPageForward,
    this.onStoryIndexChanged,
  }) : super(key: key);

  /// Function to build story content
  final StoryItemBuilder itemBuilder;

  /// Function to build story content
  /// Components with gesture actions are expected
  /// Placed above the story gestures.
  final StoryItemBuilder? gestureItemBuilder;

  /// decides length of story for each page
  final StoryConfigFunction storyLength;

  /// length of [StoryPageView]
  final int pageLength;

  /// Initial index of story for each page
  final StoryConfigFunction? initialStoryIndex;

  /// padding of [Indicators]
  final EdgeInsetsGeometry indicatorPadding;

  /// duration of [Indicators]
  final Duration indicatorDuration;

  /// Called when the very last story is finished.
  ///
  /// Functions like "Navigator.pop(context)" is expected.
  final VoidCallback? onPageLimitReached;

  /// initial index for [StoryPageView]
  final int initialPage;

  /// Color under the Stories which is visible when the cube transition is in progress
  final Color backgroundColor;

  /// A stream with [IndicatorAnimationCommand] to force pause or continue inticator animation
  /// Useful when you need to show any popup over the story
  final ValueNotifier<IndicatorAnimationCommand>? indicatorAnimationController;

  /// Called whenever the user holds down a story
  /// Useful when displaying a video and you need to pause the video
  final VoidCallback? onStoryPaused;

  /// Called whenever the user stops holding down a story
  /// Useful when displaying a video and you need to unpause the video
  final VoidCallback? onStoryUnpaused;

  /// Called whenever the user is going backwards to a new page
  final void Function(int newPageIndex)? onPageBack;

  /// Called whenever the user is going forwards to a new page
  final void Function(int newPageIndex)? onPageForward;

  /// Called whenever the user is clicks to go back or forward a story
  final void Function(int newStoryIndex)? onStoryIndexChanged;

  @override
  StoryPageViewState createState() => StoryPageViewState();
}

class StoryPageViewState extends State<StoryPageView> {
  PageController? pageController;

  double currentPageValue = 1;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: widget.initialPage);

    currentPageValue = widget.initialPage.toDouble();

    pageController!.addListener(() {
      setState(() {
        currentPageValue = pageController!.page!;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: PageView.builder(
        onPageChanged: (int newPage) {
          bool hasClients = pageController!.hasClients;
          int oldPage = pageController!.page!.toInt();
          if (hasClients && oldPage >= newPage) {
            widget.onPageBack?.call(newPage);
            widget.onStoryIndexChanged?.call(
              widget.storyLength(newPage) - 1,
            );
          } else if (hasClients && oldPage < newPage) {
            widget.onPageForward?.call(newPage);
            widget.onStoryIndexChanged?.call(0);
          }
        },
        controller: pageController,
        itemCount: widget.pageLength,
        itemBuilder: (context, index) {
          final isLeaving = (index - currentPageValue) <= 0;
          final t = (index - currentPageValue);
          final rotationY = lerpDouble(0, 30, t)!;
          const maxOpacity = 0.8;
          final num opacity =
              lerpDouble(0, maxOpacity, t.abs())!.clamp(0.0, maxOpacity);
          final isPaging = opacity != maxOpacity;
          final transform = Matrix4.identity();
          transform.setEntry(3, 2, 0.003);
          transform.rotateY(-rotationY * (pi / 180.0));
          return Transform(
            alignment: isLeaving ? Alignment.centerRight : Alignment.centerLeft,
            transform: transform,
            child: Stack(
              children: [
                StoryPageFrame.wrapped(
                  pageLength: widget.pageLength,
                  storyLength: widget.storyLength(index),
                  initialStoryIndex: widget.initialStoryIndex?.call(index) ?? 0,
                  pageIndex: index,
                  animateToPage: (index) {
                    pageController!.animateToPage(index,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.ease);
                  },
                  isCurrentPage: currentPageValue == index,
                  isPaging: isPaging,
                  onPageLimitReached: widget.onPageLimitReached,
                  itemBuilder: widget.itemBuilder,
                  gestureItemBuilder: widget.gestureItemBuilder,
                  indicatorDuration: widget.indicatorDuration,
                  indicatorPadding: widget.indicatorPadding,
                  indicatorAnimationController:
                      widget.indicatorAnimationController,
                  onStoryPaused: widget.onStoryPaused,
                  onStoryUnpaused: widget.onStoryUnpaused,
                  onStoryIndexChanged: widget.onStoryIndexChanged,
                ),
                if (isPaging && !isLeaving)
                  Positioned.fill(
                    child: Opacity(
                      opacity: opacity as double,
                      child: const ColoredBox(
                        color: Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class StoryPageFrame extends StatefulWidget {
  const StoryPageFrame._({
    Key? key,
    required this.storyLength,
    required this.initialStoryIndex,
    required this.pageIndex,
    required this.isCurrentPage,
    required this.isPaging,
    required this.itemBuilder,
    required this.gestureItemBuilder,
    required this.indicatorDuration,
    required this.indicatorPadding,
    required this.indicatorAnimationController,
    required this.onStoryPaused,
    required this.onStoryUnpaused,
  }) : super(key: key);
  final int storyLength;
  final int initialStoryIndex;
  final int pageIndex;
  final bool isCurrentPage;
  final bool isPaging;
  final StoryItemBuilder itemBuilder;
  final StoryItemBuilder? gestureItemBuilder;
  final Duration indicatorDuration;
  final EdgeInsetsGeometry indicatorPadding;
  final ValueNotifier<IndicatorAnimationCommand>? indicatorAnimationController;
  final Function()? onStoryPaused;
  final Function()? onStoryUnpaused;

  static Widget wrapped({
    required int pageIndex,
    required int pageLength,
    required ValueChanged<int> animateToPage,
    required int storyLength,
    required int initialStoryIndex,
    required bool isCurrentPage,
    required bool isPaging,
    required VoidCallback? onPageLimitReached,
    required StoryItemBuilder itemBuilder,
    StoryItemBuilder? gestureItemBuilder,
    required Duration indicatorDuration,
    required EdgeInsetsGeometry indicatorPadding,
    required ValueNotifier<IndicatorAnimationCommand>?
        indicatorAnimationController,
    required Function()? onStoryPaused,
    required Function()? onStoryUnpaused,
    required Function(int newStoryIndex)? onStoryIndexChanged,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => StoryLimitController(),
        ),
        ChangeNotifierProvider(
          create: (context) => StoryStackController(
            onStoryIndexChanged: onStoryIndexChanged,
            storyLength: storyLength,
            onPageBack: () {
              if (pageIndex != 0) {
                animateToPage(pageIndex - 1);
              }
            },
            onPageForward: () {
              if (pageIndex == pageLength - 1) {
                context
                    .read<StoryLimitController>()
                    .onPageLimitReached(onPageLimitReached);
              } else {
                animateToPage(pageIndex + 1);
              }
            },
            initialStoryIndex: initialStoryIndex,
          ),
        ),
      ],
      child: StoryPageFrame._(
        storyLength: storyLength,
        initialStoryIndex: initialStoryIndex,
        pageIndex: pageIndex,
        isCurrentPage: isCurrentPage,
        isPaging: isPaging,
        itemBuilder: itemBuilder,
        gestureItemBuilder: gestureItemBuilder,
        indicatorDuration: indicatorDuration,
        indicatorPadding: indicatorPadding,
        indicatorAnimationController: indicatorAnimationController,
        onStoryPaused: onStoryPaused,
        onStoryUnpaused: onStoryUnpaused,
      ),
    );
  }

  @override
  StoryPageFrameState createState() => StoryPageFrameState();
}

class StoryPageFrameState extends State<StoryPageFrame>
    with
        AutomaticKeepAliveClientMixin<StoryPageFrame>,
        SingleTickerProviderStateMixin {
  late AnimationController animationController;

  late VoidCallback listener;

  @override
  void initState() {
    super.initState();

    listener = () {
      if (widget.isCurrentPage) {
        IndicatorAnimationCommand? command =
            widget.indicatorAnimationController?.value;
        if (command != null) {
          if (command.pause == true) {
            animationController.stop();
          } else if (command.resume == true) {
            animationController.forward();
          } else if (command.duration != null) {
            animationController.reset();
            animationController.duration = command.duration;
          }
        }
      }
    };
    animationController = AnimationController(
      vsync: this,
      duration: widget.indicatorDuration,
    )..addStatusListener(
        (status) {
          if (status == AnimationStatus.completed) {
            context.read<StoryStackController>().increment(
                restartAnimation: () => animationController.forward(from: 0));
          }
        },
      );
    widget.indicatorAnimationController?.addListener(listener);
  }

  @override
  void dispose() {
    widget.indicatorAnimationController?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      fit: StackFit.loose,
      alignment: Alignment.topLeft,
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
        Positioned.fill(
          child: widget.itemBuilder(
            context,
            widget.pageIndex,
            context.watch<StoryStackController>().value,
          ),
        ),
        Container(
          height: 50,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 10,
                blurRadius: 20,
              ),
            ],
          ),
        ),
        Indicators(
          storyLength: widget.storyLength,
          animationController: animationController,
          isCurrentPage: widget.isCurrentPage,
          isPaging: widget.isPaging,
          padding: widget.indicatorPadding,
        ),
        Gestures(
          onStoryUnpaused: widget.onStoryUnpaused,
          onStoryPaused: widget.onStoryPaused,
          animationController: animationController,
        ),
        Positioned.fill(
          child: widget.gestureItemBuilder?.call(
                context,
                widget.pageIndex,
                context.watch<StoryStackController>().value,
              ) ??
              const SizedBox.shrink(),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// Simple class to issue commands using indicatorAnimationController.
class IndicatorAnimationCommand {
  final bool? pause;
  final bool? resume;
  final Duration? duration;

  IndicatorAnimationCommand({
    this.pause,
    this.resume,
    this.duration,
  });
}
