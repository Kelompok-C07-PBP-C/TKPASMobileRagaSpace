import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, this.onPressed, this.loading = false, this.colors});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: enabled ? 1 : 0.6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors ?? [cs.primary, cs.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: (colors != null ? colors!.first : cs.primary).withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              foregroundColor: Colors.white,
              textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: loading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(label, key: const ValueKey('text')),
            ),
          ),
        ),
      ),
    );
  }
}