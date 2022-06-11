import 'package:flutter/cupertino.dart';

/// Notify current stack index
class StoryStackController extends ValueNotifier<int> {
  StoryStackController({
    required this.storyLength,
    required this.onPageForward,
    required this.onPageBack,
    this.onStoryIndexChanged,
    initialStoryIndex = 0,
  }) : super(initialStoryIndex) {
    onStoryIndexChanged?.call(initialStoryIndex);
  }
  final int storyLength;
  final VoidCallback onPageForward;
  final VoidCallback onPageBack;
  final Function(int newStoryIndex)? onStoryIndexChanged;

  int get limitIndex => storyLength - 1;

  void increment({
    VoidCallback? restartAnimation,
    VoidCallback? completeAnimation,
  }) {
    if (value == limitIndex) {
      completeAnimation?.call();
      onPageForward();
    } else {
      value++;
      restartAnimation?.call();
      onStoryIndexChanged?.call(value);
    }
  }

  void decrement() {
    if (value == 0) {
      onPageBack();
    } else {
      value--;
      onStoryIndexChanged?.call(value);
    }
  }
}
