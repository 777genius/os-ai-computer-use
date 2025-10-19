import 'package:flutter/widgets.dart';

class DropDoneDetails {
  const DropDoneDetails({this.files = const []});
  final List<_StubDragFile> files;
}

class _StubDragFile {
  const _StubDragFile();
  String? get path => null;
  String get name => '';
  Future<List<int>> readAsBytes() async => <int>[];
}

class DropTarget extends StatelessWidget {
  final Widget child;
  final void Function(dynamic)? onDragEntered;
  final void Function(dynamic)? onDragExited;
  final void Function(DropDoneDetails)? onDragDone;
  const DropTarget({super.key, required this.child, this.onDragEntered, this.onDragExited, this.onDragDone});

  @override
  Widget build(BuildContext context) => child;
}



