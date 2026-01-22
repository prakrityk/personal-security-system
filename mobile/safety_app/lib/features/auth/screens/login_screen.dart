// import 'package:flutter/material.dart';
// import 'package:safety_app/core/widgets/animated_bottom_button.dart';
// import 'package:safety_app/core/widgets/app_text_field.dart';
// import 'package:safety_app/features/intent/screens/role_intent_screen.dart';
// import '../../../core/theme/app_colors.dart';
// import '../../../core/theme/app_text_styles.dart';

// class LoginScreen extends StatelessWidget {
//   const LoginScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     return Scaffold(
//       backgroundColor: isDark
//           ? AppColors.darkBackground
//           : AppColors.lightBackground,
//       body: SafeArea(
//         child: Column(
//           children: [
//             /// 1️⃣ Main content
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     /// Title
//                     Text("Welcome back", style: AppTextStyles.heading),
//                     const SizedBox(height: 8),
//                     Text("Login to continue", style: AppTextStyles.body),

//                     const SizedBox(height: 40),

//                     /// Phone Number
//                     AppTextField(
//                       label: "Phone Number",
//                       hint: "98XXXXXXXX",
//                       keyboardType: TextInputType.phone,
//                     ),

//                     const SizedBox(height: 16),

//                     /// Password
//                     AppTextField(label: "Password", obscureText: true),

//                     const SizedBox(height: 12),

//                     /// Forgot Password (optional)
//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: TextButton(
//                         onPressed: () {
//                           // Navigate to reset flow later
//                         },
//                         child: Text(
//                           "Forgot password?",
//                           style: AppTextStyles.caption.copyWith(
//                             color: AppColors.primaryGreen,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             /// 2️⃣ Bottom Login Button
//             Padding(
//               padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
//               child: AnimatedBottomButton(
//                 label: "Login",
//                 usePositioned: false,
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (_) => const RoleIntentScreen()),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/features/intent/screens/role_intent_screen.dart';
import 'package:safety_app/features/onboarding/screens/lets_get_started_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            /// 1️⃣ Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Title
                    Text("Welcome back", style: AppTextStyles.heading),
                    const SizedBox(height: 8),
                    Text("Login to continue", style: AppTextStyles.body),

                    const SizedBox(height: 40),

                    /// Phone Number
                    AppTextField(
                      label: "Phone Number",
                      hint: "98XXXXXXXX",
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 16),

                    /// Password
                    AppTextField(label: "Password", obscureText: true),

                    const SizedBox(height: 12),

                    /// Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Forgot password flow
                        },
                        child: Text(
                          "Forgot password?",
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    /// 👉 Sign up prompt (NEW)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don’t have an account?",
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            /// Signup flow starts with phone number
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LetsGetStartedScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Sign up",
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            /// 2️⃣ Bottom Login Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: "Login",
                usePositioned: false,
                onPressed: () {
                  // TODO:
                  // Authenticate user
                  // Check onboarding completion
                  // Navigate accordingly

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoleIntentScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
