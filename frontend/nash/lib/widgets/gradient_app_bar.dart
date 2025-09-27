import 'package:flutter/material.dart';
import 'package:nash/theme/app_theme.dart';

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final double height;
  const GradientAppBar({Key? key, this.title, this.actions, this.height = 72}) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(gradient: AppTheme.appBarGradient, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))]),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: [
              if (title != null) DefaultTextStyle(style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.bold), child: title!),
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}
