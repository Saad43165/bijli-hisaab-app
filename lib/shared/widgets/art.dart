import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Bundled 3D illustrations (Microsoft Fluent Emoji, MIT licence —
/// assets/images/LICENSE-fluent-emoji.txt).
class Art {
  Art._();

  static const String _d = 'assets/images/3d/';

  static const brandBolt = 'assets/images/brand_bolt.png';

  static const barChart = '${_d}bar_chart.png';
  static const battery = '${_d}battery.png';
  static const bell = '${_d}bell.png';
  static const camera = '${_d}camera_with_flash.png';
  static const chartUp = '${_d}chart_increasing.png';
  static const check = '${_d}check_mark_button.png';
  static const clipboard = '${_d}clipboard.png';
  static const storm = '${_d}cloud_with_lightning.png';
  static const cooking = '${_d}cooking.png';
  static const desktop = '${_d}desktop_computer.png';
  static const droplet = '${_d}droplet.png';
  static const plug = '${_d}electric_plug.png';
  static const fire = '${_d}fire.png';
  static const gear = '${_d}gear.png';
  static const globe = '${_d}globe_with_meridians.png';
  static const bolt = '${_d}high_voltage.png';
  static const hourglass = '${_d}hourglass_not_done.png';
  static const house = '${_d}house.png';
  static const laptop = '${_d}laptop.png';
  static const bulb = '${_d}light_bulb.png';
  static const lock = '${_d}locked.png';
  static const search = '${_d}magnifying_glass_tilted_right.png';
  static const memo = '${_d}memo.png';
  static const phone = '${_d}mobile_phone.png';
  static const moneyBag = '${_d}money_bag.png';
  static const office = '${_d}office_building.png';
  static const party = '${_d}party_popper.png';
  static const water = '${_d}potable_water.png';
  static const receipt = '${_d}receipt.png';
  static const shield = '${_d}shield.png';
  static const shower = '${_d}shower.png';
  static const snowflake = '${_d}snowflake.png';
  static const sparkles = '${_d}sparkles.png';
  static const calendar = '${_d}spiral_calendar.png';
  static const stopwatch = '${_d}stopwatch.png';
  static const sun = '${_d}sun.png';
  static const shirt = '${_d}t_shirt.png';
  static const call = '${_d}telephone_receiver.png';
  static const tv = '${_d}television.png';
  static const toolbox = '${_d}toolbox.png';
  static const warning = '${_d}warning.png';
  static const wind = '${_d}wind_face.png';

  /// Picture for an appliance category.
  static String forCategory(String category) => switch (category) {
        'cooling' => snowflake,
        'heating' => fire,
        'kitchen' => cooking,
        'laundry' => shirt,
        'lighting' => bulb,
        'entertainment' => tv,
        'pump' => water,
        _ => plug,
      };

  /// Picture for a specific appliance name, falling back to its category.
  static String forAppliance(String name, String category) {
    final n = name.toLowerCase();
    if (n.contains('fan') || n.contains('cooler')) return wind;
    if (n.contains('fridge') || n.contains('refrigerator') || n.contains('freezer')) return snowflake;
    if (n.contains('dispenser')) return droplet;
    if (n.contains('laptop')) return laptop;
    if (n.contains('pc') || n.contains('computer')) return desktop;
    if (n.contains('router') || n.contains('wi-fi') || n.contains('wifi')) return globe;
    if (n.contains('ups') || n.contains('inverter battery')) return battery;
    if (n.contains('geyser')) return shower;
    if (n.contains('motor') || n.contains('pump')) return water;
    if (n.contains('iron') || n.contains('washing')) return shirt;
    return forCategory(category);
  }
}

/// A 3D illustration, decoded at the exact pixel size it's shown at so it
/// stays crisp and light on memory.
class ArtImage extends StatelessWidget {
  const ArtImage(this.asset, {super.key, this.size = 40});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      asset,
      width: size,
      height: size,
      cacheWidth: px,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    );
  }
}

/// Illustration on a soft rounded tile — the app's standard leading visual.
class ArtTile extends StatelessWidget {
  const ArtTile(this.asset, {super.key, this.size = 46, this.tint, this.onNavy = false});

  final String asset;
  final double size;

  /// Background tint; defaults to a warm neutral.
  final Color? tint;

  /// Navy tile (brand mark style).
  final bool onNavy;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bg = onNavy
        ? AppColors.navy
        : (tint ?? AppColors.amber).withValues(alpha: p.isDark ? 0.14 : 0.12);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: ArtImage(asset, size: size * 0.68),
    );
  }
}
