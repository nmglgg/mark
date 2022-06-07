/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/er/fetcher.dart';
import 'package:pixez/er/hoster.dart';
import 'package:pixez/er/kver.dart';
import 'package:pixez/network/onezero_client.dart';
import 'package:pixez/page/history/history_store.dart';
import 'package:pixez/page/novel/history/novel_history_store.dart';
import 'package:pixez/page/splash/splash_page.dart';
import 'package:pixez/page/splash/splash_store.dart';
import 'package:pixez/store/account_store.dart';
import 'package:pixez/store/book_tag_store.dart';
import 'package:pixez/store/mute_store.dart';
import 'package:pixez/store/save_store.dart';
import 'package:pixez/store/tag_history_store.dart';
import 'package:pixez/store/top_store.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:flutter/foundation.dart';

// Fictitious brand color.
const _brandBlue = Color(0xFF1E88E5);

CustomColors lightCustomColors = const CustomColors(danger: Color(0xFFE53935));
CustomColors darkCustomColors = const CustomColors(danger: Color(0xFFEF9A9A));

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
final UserSetting userSetting = UserSetting();
final SaveStore saveStore = SaveStore();
final MuteStore muteStore = MuteStore();
final AccountStore accountStore = AccountStore();
final TagHistoryStore tagHistoryStore = TagHistoryStore();
final HistoryStore historyStore = HistoryStore();
final NovelHistoryStore novelHistoryStore = NovelHistoryStore();
final TopStore topStore = TopStore();
final BookTagStore bookTagStore = BookTagStore();
OnezeroClient onezeroClient = OnezeroClient();
final SplashStore splashStore = SplashStore(onezeroClient);
final Fetcher fetcher = new Fetcher();
final KVer kVer = KVer();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

main() async {
  // HttpOverrides.global = new MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android &&
      Constants.isGooglePlay) {
    InAppPurchaseAndroidPlatformAddition.enablePendingPurchases();
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  AppLifecycleState? _appState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _appState = state;
    });
  }

  @override
  void dispose() {
    saveStore.dispose();
    topStore.dispose();
    fetcher.stop();
    if (Platform.isIOS) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    Hoster.init();
    Hoster.syncRemote();
    userSetting.init();
    accountStore.fetch();
    bookTagStore.init();
    muteStore.fetchBanUserIds();
    muteStore.fetchBanIllusts();
    muteStore.fetchBanTags();
    initMethod();
    kVer.open();
    fetcher.start();
    super.initState();
    if (Platform.isIOS) WidgetsBinding.instance.addObserver(this);
  }

  initMethod() async {
    if (userSetting.disableBypassSni) return;
  }

  Future<void> clean() async {
    final path = await saveStore.findLocalPath();
    Directory directory = Directory(path);
    List<FileSystemEntity> list = directory.listSync(recursive: true);
    if (list.length > 180) {
      directory.deleteSync(recursive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final botToastBuilder = BotToastInit();
      final myBuilder = (BuildContext context, Widget? widget) {
        if (userSetting.nsfwMask) {
          final needShowMask = (Platform.isAndroid
              ? (_appState == AppLifecycleState.paused ||
                  _appState == AppLifecycleState.paused)
              : _appState == AppLifecycleState.inactive);
          return Stack(
            children: [
              widget ?? Container(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: needShowMask
                    ? Container(
                        color: Theme.of(context).canvasColor,
                        child: Center(
                          child: Icon(Icons.privacy_tip_outlined),
                        ),
                      )
                    : null,
              )
            ],
          );
        } else {
          return widget;
        }
      };
      return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          // On Android S+ devices, use the provided dynamic color scheme.
          // (Recommended) Harmonize the dynamic color scheme' built-in semantic colors.
          lightColorScheme = lightDynamic.harmonized();
          // (Optional) Customize the scheme as desired. For example, one might
          // want to use a brand color to override the dynamic [ColorScheme.secondary].
          lightColorScheme = lightColorScheme.copyWith(secondary: _brandBlue);
          // (Optional) If applicable, harmonize custom colors.
          lightCustomColors = lightCustomColors.harmonized(lightColorScheme);

          // Repeat for the dark color scheme.
          darkColorScheme = darkDynamic.harmonized();
          darkColorScheme = darkColorScheme.copyWith(secondary: _brandBlue);
          darkCustomColors = darkCustomColors.harmonized(darkColorScheme);
        } else {
          // Otherwise, use fallback schemes.
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: _brandBlue,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: _brandBlue,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          navigatorObservers: [BotToastNavigatorObserver(), routeObserver],
          locale: userSetting.locale,
          home: Builder(builder: (context) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarDividerColor: Colors.transparent,
                  statusBarColor: Colors.transparent,
                ),
                child: SplashPage());
          }),
          title: 'PixEz',
          builder: (context, child) {
            if (Platform.isIOS) child = myBuilder(context, child);
            child = botToastBuilder(context, child);
            return child;
          },
          themeMode: userSetting.themeMode,
          theme: ThemeData(
            colorScheme: lightColorScheme,
            extensions: [lightCustomColors],
            useMaterial3: true
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            extensions: [darkCustomColors],
            useMaterial3: true
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales, // Add this line
        );
      });
    });
  }
}

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    required this.danger,
  });

  final Color? danger;

  @override
  CustomColors copyWith({Color? danger}) {
    return CustomColors(
      danger: danger ?? this.danger,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      danger: Color.lerp(danger, other.danger, t),
    );
  }

  CustomColors harmonized(ColorScheme dynamic) {
    return copyWith(danger: danger!.harmonizeWith(dynamic.primary));
  }
}
