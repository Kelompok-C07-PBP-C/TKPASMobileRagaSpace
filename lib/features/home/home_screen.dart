import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:marco/services/api.dart';
import 'package:marco/services/base_url_resolver.dart';
import 'package:marco/theme/aurora_palette.dart';
import 'package:marco/widgets/aurora_backdrop.dart';
import 'package:marco/widgets/aurora_route.dart';
import 'package:marco/widgets/twinkle_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../account_settings/account_settings_screen.dart';
import '../authentication/login_screen.dart';

part 'sections/home_state.dart';
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
