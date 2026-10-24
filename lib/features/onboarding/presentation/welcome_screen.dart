import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color background = Color(0xFF050614);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color mutedText = Color(0xFF9695A8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1C),
      body: SizedBox.expand(
        child: ClipRect(
          child: Stack(
            children: [
              // ------------------------------------------------
              // HERO IMAGE
              // ------------------------------------------------
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 390,
                child: Image.asset(
                  'assets/images/splash_mentor.png',
                  fit: BoxFit.cover,
                ),
              ),

              // Dark gradient over image
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 440,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x00050614),
                        Color(0xFF050614),
                      ],
                      stops: [0.35, 0.65, 1.0],
                    ),
                  ),
                ),
              ),

              // ------------------------------------------------
              // APP NAME
              // ------------------------------------------------
              Positioned(
                top: 66,
                left: 20,
                child: const Text(
                  'Evolyn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              // AI CAREER COMPANION BADGE
              Positioned(
                top: 67,
                right: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xAA111326),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: purple.withOpacity(0.45)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF58D9FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'AI CAREER MENTOR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ------------------------------------------------
              // MAIN CONTENT
              // ------------------------------------------------
              Positioned(
                left: 21,
                right: 21,
                bottom: 25,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meet the future\n'
                      'you’re building\n'
                      'toward.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.02,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.8,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'A personal AI mentor that turns your career\n'
                      'ambition into a clear, adaptive path—one focused\n'
                      'day at a time.',
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 13.5,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // START BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          context.push('/signup');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purple,
                          foregroundColor: Colors.white,
                          elevation: 10,
                          shadowColor: purple.withOpacity(0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Start your journey',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_outward, size: 17),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 19),

                    // SIGN IN
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: mutedText,
                            fontSize: 11.5,
                          ),
                          children: [
                            const TextSpan(text: 'Already have a path? '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: GestureDetector(
                                onTap: () {
                                  context.push('/signin');
                                },
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: Color(0xFFA78BFA),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // PRIVACY
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: mutedText.withOpacity(0.7),
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Private by design · Built around your goals',
                            style: TextStyle(color: mutedText, fontSize: 9.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
