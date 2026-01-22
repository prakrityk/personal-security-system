import 'package:flutter/material.dart';

/// AppTextField with validation support
/// Replace your existing AppTextField with this version
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? suffixIcon;
  final String? Function(String?)? validator; // ✅ NEW: Added validator
  final int? maxLines;
  final void Function(String)? onChanged;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
    this.validator, // ✅ NEW
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureTextState = false;

  @override
  void initState() {
    super.initState();
    _obscureTextState = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),

        // Text Field with Validation Support
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _obscureTextState,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          validator: widget.validator, // ✅ NEW: Validation support
          onChanged: widget.onChanged,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: widget.enabled
                ? (isDark ? Colors.white : Colors.black)
                : Colors.grey,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            // Toggle password visibility
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscureTextState
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureTextState = !_obscureTextState;
                      });
                    },
                  )
                : widget.suffixIcon,
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.green, // Your primary color
                width: 2,
              ),
            ),
            // ✅ NEW: Error borders for validation
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            // ✅ NEW: Error text styling
            errorStyle: TextStyle(color: Colors.red[400], fontSize: 12),
          ),
        ),
      ],
    );
  }
}
