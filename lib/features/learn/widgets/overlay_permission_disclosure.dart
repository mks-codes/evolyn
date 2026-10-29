import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows an explanatory disclosure before the app opens Android's
/// "Display over other apps" settings.
///
/// A successful result means the user acknowledged this disclosure and chose
/// to continue to Android settings. It does NOT mean Android permission has
/// been granted. Always check the actual overlay permission after returning
/// from system settings.
class OverlayPermissionDisclosure {
  OverlayPermissionDisclosure._();

  // Bump v1 if the purpose or scope of the overlay permission changes.
  static const String _keyPrefix = 'evolyn.overlay_disclosure.v1.';

  /// Returns true when the user may continue to the existing Android overlay
  /// permission flow. Returns false when they choose "Not now" or the screen
  /// has been disposed.
  static Future<bool> showIfNeeded(BuildContext context) async {
    if (!context.mounted) return false;

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final key = '$_keyPrefix$userId';

    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(key) == true) return true;
    } catch (error) {
      // Fail closed with respect to skipping the disclosure: show it even if
      // the acknowledgement could not be read from local storage.
      debugPrint('[OverlayDisclosure] Could not read acknowledgement: $error');
    }

    if (!context.mounted) return false;

    final copy = _copyFor(Localizations.localeOf(context).languageCode);
    final acknowledged = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.picture_in_picture_alt_rounded, size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(copy.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            '${copy.body}\n\n${copy.permissionNote}',
            style: const TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(copy.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(copy.continueLabel),
          ),
        ],
      ),
    );

    if (acknowledged != true || !context.mounted) return false;

    // Persist the acknowledgement, not the Android permission state.
    try {
      preferences ??= await SharedPreferences.getInstance();
      await preferences.setBool(key, true);
    } catch (error) {
      // Continue because the user explicitly acknowledged the disclosure;
      // it may be shown again next time if persistence failed.
      debugPrint('[OverlayDisclosure] Could not save acknowledgement: $error');
    }

    return context.mounted;
  }

  static _OverlayDisclosureCopy _copyFor(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return const _OverlayDisclosureCopy(
          title: 'स्टडी टाइमर को स्क्रीन पर दिखाएँ',
          body:
              'Evolyn दूसरे ऐप इस्तेमाल करते समय आपका छोटा स्टडी टाइमर स्क्रीन पर दिखा सकता है, ताकि आप अपने अध्ययन सत्र का समय देख सकें। “अन्य ऐप्स के ऊपर दिखाएँ” अनुमति का उपयोग केवल इस टाइमर को दिखाने के लिए किया जाता है। यह अनुमति अपने आप Evolyn को दूसरे ऐप्स की स्क्रीन पढ़ने या कीबोर्ड पर टाइप की गई चीज़ें रिकॉर्ड करने की सुविधा नहीं देती।',
          permissionNote:
              'Continue चुनने पर Android की सेटिंग खुलेगी। वहाँ आपको अनुमति खुद चालू करनी होगी। Continue चुनने से अनुमति अपने आप चालू नहीं होती। आप Not now चुन सकते हैं और जहाँ संभव हो, टाइमर ओवरले के बिना Evolyn का इस्तेमाल जारी रख सकते हैं।',
          continueLabel: 'सेटिंग्स पर जाएँ',
          notNow: 'अभी नहीं',
        );
      case 'mr':
        return const _OverlayDisclosureCopy(
          title: 'स्टडी टायमर स्क्रीनवर दिसू द्या',
          body:
              'तुम्ही दुसरे अॅप वापरत असताना Evolyn तुमचा छोटा स्टडी टायमर स्क्रीनवर दाखवू शकते, जेणेकरून अभ्यासाचा वेळ लक्षात ठेवता येईल. “इतर अॅप्सवर दाखवा” ही परवानगी फक्त टायमरचा ओव्हरले दाखवण्यासाठी वापरली जाते. या परवानगीमुळे Evolyn ला इतर अॅप्समधील स्क्रीनवरील मजकूर वाचता येत नाही किंवा कीबोर्डवरील टायपिंग नोंदवता येत नाही.',
          permissionNote:
              'Continue निवडल्यावर Android सेटिंग्ज उघडतील. तिथे तुम्हाला ही परवानगी स्वतः सुरू करावी लागेल. Continue निवडल्याने परवानगी आपोआप मिळत नाही. तुम्ही Not now निवडून, शक्य असेल तिथे ओव्हरलेशिवाय Evolyn वापरू शकता.',
          continueLabel: 'सेटिंग्ज उघडा',
          notNow: 'आत्ता नको',
        );
      default:
        return const _OverlayDisclosureCopy(
          title: 'Keep your study timer visible',
          body:
              'Evolyn can show a small study timer over other apps so you can keep track of your session while studying elsewhere. The “Display over other apps” permission is used to display this timer overlay. By itself, this permission does not allow Evolyn to read other apps’ screen contents or capture keystrokes.',
          permissionNote:
              'Continue opens Android settings. You must enable the permission there. Choosing Continue does not grant the permission by itself. You can choose Not now and continue using Evolyn without the timer overlay where available.',
          continueLabel: 'Continue to settings',
          notNow: 'Not now',
        );
    }
  }
}

class _OverlayDisclosureCopy {
  const _OverlayDisclosureCopy({
    required this.title,
    required this.body,
    required this.permissionNote,
    required this.continueLabel,
    required this.notNow,
  });

  final String title;
  final String body;
  final String permissionNote;
  final String continueLabel;
  final String notNow;
}
