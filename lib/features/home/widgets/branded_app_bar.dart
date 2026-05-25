import 'package:flutter/material.dart';
import 'package:cyclezen/core/theme/app_theme.dart';
import 'package:cyclezen/core/constants/app_assets.dart';

class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> actions;
  const BrandedAppBar({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF061A1C),
            AppTheme.primaryDark,
            const Color(0xFF0A3032),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.greenAccent.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: AppTheme.greenAccent.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              // ── Logo with glow ring ──
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.greenAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    AppAssets.logoMark,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 9),

              // ── Brand text ──
              Expanded(
                child: Text(
                  'CycleZen',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.3,
                    shadows: [
                      Shadow(
                        color: Color(0x40000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── Frosted action buttons ──
              ...actions.map((action) => Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: action,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(54);
}
