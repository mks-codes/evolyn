
import 'dart:async';

import 'package:flutter/material.dart';

class TopMessage {
  TopMessage._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String text, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted || text.trim().isEmpty) return;

    // Replace any existing notification.
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
    _timer = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        final topInset = MediaQuery.of(overlayContext).padding.top;

        return Positioned(
          top: topInset + 12,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _dismiss(entry),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF251B4B),
                      Color(0xFF151630),
                      Color(0xFF101126),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFA78BFA).withOpacity(0.65),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA78BFA).withOpacity(0.13),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFC6B8FF),
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Color(0xFFF4F0FF),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFB9ACDE),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(duration, () => _dismiss(entry));
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;

    final entry = _entry;
    _entry = null;
    entry?.remove();
  }

  static void _dismiss(OverlayEntry entry) {
    // An older timer must not remove a newer notification.
    if (!identical(_entry, entry)) return;

    _timer?.cancel();
    _timer = null;
    _entry = null;
    entry.remove();
  }
}
