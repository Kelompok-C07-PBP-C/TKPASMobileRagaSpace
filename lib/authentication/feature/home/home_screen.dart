import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:tk2ragaspace/services/api.dart';
import 'package:tk2ragaspace/services/base_url_resolver.dart';
import 'package:tk2ragaspace/theme/aurora_palette.dart';
import 'package:tk2ragaspace/widgets/aurora_backdrop.dart';
import 'package:tk2ragaspace/widgets/aurora_route.dart';
import 'package:tk2ragaspace/widgets/twinkle_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../account_settings/account_settings_screen.dart';
import '../authentication/login_screen.dart';

part 'sections/home_state.dart';
part 'sections/home_hero_section.dart';
part 'sections/home_top_venues_section.dart';
part 'sections/nav_section.dart';
part 'sections/testimonials_section.dart';
part 'sections/wishlist_section.dart';
part 'sections/promo_section.dart';
part 'sections/shared_ui_section.dart';
part 'sections/booking_section.dart';
part 'sections/home_detail.dart';
part 'sections/home_detail_screen.dart';
part 'sections/home_detail_content.dart';
part 'sections/home_detail_actions.dart';
part 'sections/home_detail_booking.dart';
part 'sections/home_hero_helpers.dart';
part 'models/home_screen_models.dart';
part 'catalog/home_screen_catalog.dart';
part 'wishlist/home_screen_wishlist.dart';
part 'bookings/home_screen_bookings.dart';
part 'widgets/home_screen_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

@visibleForTesting
void debugSetFadeSlideInDisabledForTests(bool value) {
  disableFadeSlideInAnimationsForTests = value;
}