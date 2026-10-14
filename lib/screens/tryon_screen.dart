import 'package:flutter/material.dart';

import '../models/garment.dart';
import '../theme.dart';
import '../widgets/tryon_view.dart';

class TryOnScreen extends StatefulWidget {
  const TryOnScreen({
    required this.garment,
    this.initialMode = TryOnMode.viewer3d,
    super.key,
  });

  final Garment garment;
  final TryOnMode initialMode;

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  late TryOnMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    final isCamera = _mode == TryOnMode.camera;
    final background = isCamera ? const Color(0xFF24231F) : paper;
    final foreground = isCamera ? Colors.white : ink;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: foreground,
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        title: Text(
          widget.garment.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SegmentedButton<TryOnMode>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                foregroundColor: foreground,
                selectedForegroundColor: ink,
                selectedBackgroundColor: sage,
                side: BorderSide(color: isCamera ? Colors.white38 : line),
              ),
              segments: const [
                ButtonSegment(
                  value: TryOnMode.viewer3d,
                  icon: Icon(Icons.view_in_ar_outlined),
                  label: Text('3D view'),
                ),
                ButtonSegment(
                  value: TryOnMode.camera,
                  icon: Icon(Icons.camera_alt_outlined),
                  label: Text('Try on'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
            ),
          ),
          Expanded(
            child: TryOnView(src: tryOnPageUrlFor(widget.garment, _mode)),
          ),
        ],
      ),
    );
  }
}
