import 'package:material_ui/material_ui.dart';

/// Curated icon catalogue. Trackers persist the string key; keeping icons as
/// const references lets Flutter tree-shake the icon font.
abstract final class TrackerIcons {
  static const fallback = Icons.task_alt_rounded;

  static const Map<String, Map<String, IconData>> categories = {
    'Faith & mind': {
      'mosque': Icons.mosque_rounded,
      'twilight': Icons.wb_twilight_rounded,
      'sunny': Icons.wb_sunny_rounded,
      'sun_low': Icons.light_mode_rounded,
      'sunset': Icons.wb_twilight_outlined,
      'moon': Icons.nights_stay_rounded,
      'star': Icons.auto_awesome_rounded,
      'book': Icons.menu_book_rounded,
      'meditate': Icons.self_improvement_rounded,
      'heart': Icons.favorite_rounded,
      'hands': Icons.volunteer_activism_rounded,
      'psychology': Icons.psychology_rounded,
    },
    'Time & sleep': {
      'alarm': Icons.alarm_rounded,
      'bed': Icons.bedtime_rounded,
      'hotel': Icons.hotel_rounded,
      'clock': Icons.schedule_rounded,
      'timer': Icons.timer_rounded,
      'hourglass': Icons.hourglass_bottom_rounded,
    },
    'Food & drink': {
      'breakfast': Icons.free_breakfast_rounded,
      'lunch': Icons.lunch_dining_rounded,
      'dinner': Icons.dinner_dining_rounded,
      'restaurant': Icons.restaurant_rounded,
      'egg': Icons.egg_alt_rounded,
      'fruit': Icons.apple_rounded,
      'bakery': Icons.bakery_dining_rounded,
      'water': Icons.water_drop_rounded,
      'drink': Icons.local_drink_rounded,
      'coffee': Icons.coffee_rounded,
      'no_food': Icons.no_food_rounded,
      'kitchen': Icons.soup_kitchen_rounded,
    },
    'Fitness & health': {
      'gym': Icons.fitness_center_rounded,
      'run': Icons.directions_run_rounded,
      'walk': Icons.directions_walk_rounded,
      'bike': Icons.directions_bike_rounded,
      'swim': Icons.pool_rounded,
      'sports': Icons.sports_martial_arts_rounded,
      'weight': Icons.monitor_weight_rounded,
      'heart_rate': Icons.monitor_heart_rounded,
      'medication': Icons.medication_rounded,
      'spa': Icons.spa_rounded,
      'bolt': Icons.bolt_rounded,
      'steps': Icons.do_not_step_rounded,
    },
    'Work & study': {
      'work': Icons.work_rounded,
      'home_work': Icons.home_work_rounded,
      'office': Icons.business_rounded,
      'laptop': Icons.laptop_mac_rounded,
      'logout': Icons.logout_rounded,
      'commute': Icons.commute_rounded,
      'school': Icons.school_rounded,
      'code': Icons.code_rounded,
      'edit': Icons.edit_note_rounded,
      'target': Icons.track_changes_rounded,
      'lightbulb': Icons.lightbulb_rounded,
      'money': Icons.savings_rounded,
    },
    'Quit & control': {
      'no_phone': Icons.phonelink_erase_rounded,
      'phone': Icons.smartphone_rounded,
      'smoke_free': Icons.smoke_free_rounded,
      'block': Icons.block_rounded,
      'shield': Icons.shield_rounded,
      'visibility_off': Icons.visibility_off_rounded,
      'tv_off': Icons.tv_off_rounded,
      'mood': Icons.mood_rounded,
    },
    'Other': {
      'check': Icons.task_alt_rounded,
      'camera': Icons.photo_camera_rounded,
      'file': Icons.description_rounded,
      'family': Icons.family_restroom_rounded,
      'people': Icons.groups_rounded,
      'call': Icons.call_rounded,
      'clean': Icons.cleaning_services_rounded,
      'nature': Icons.park_rounded,
      'music': Icons.music_note_rounded,
      'flag': Icons.flag_rounded,
      'trophy': Icons.emoji_events_rounded,
      'flame': Icons.local_fire_department_rounded,
    },
  };

  static final Map<String, IconData> all = {
    for (final c in categories.values) ...c,
  };

  static IconData resolve(String key) => all[key] ?? fallback;
}
