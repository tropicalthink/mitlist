import 'package:flutter/material.dart';

/// Semantic icon names mapped to Material [IconData] placeholders.
///
/// When SVG assets are available, this class can be updated to return
/// asset paths or a custom icon descriptor instead of [IconData].
class AppIcons {
  const AppIcons._();

  // Heroicons-solid placeholders
  static const IconData plus = Icons.add;
  static const IconData arrowLeft = Icons.arrow_back;
  static const IconData arrowRight = Icons.arrow_forward;
  static const IconData ellipsisVertical = Icons.more_vert;
  static const IconData check = Icons.check;
  static const IconData checkCircle = Icons.check_circle;
  static const IconData archiveBox = Icons.archive;
  static const IconData archiveBoxArrowDown = Icons.archive;
  static const IconData banknotes = Icons.attach_money;
  static const IconData receiptPercent = Icons.receipt_long;
  static const IconData shoppingCart = Icons.shopping_cart;
  static const IconData userCircle = Icons.account_circle;
  static const IconData userGroup = Icons.group;
  static const IconData home = Icons.home;
  static const IconData cog6Tooth = Icons.settings;
  static const IconData calendarDays = Icons.calendar_month;
  static const IconData chartBar = Icons.bar_chart;
  static const IconData clipboardDocumentList = Icons.assignment;
  static const IconData xMark = Icons.close;
  static const IconData magnifyingGlass = Icons.search;
  static const IconData funnel = Icons.filter_list;
  static const IconData squares2x2 = Icons.grid_view;
  static const IconData listBullet = Icons.format_list_bulleted;
  static const IconData share = Icons.share;
  static const IconData exclamationTriangle = Icons.warning;
  static const IconData trash = Icons.delete;
  static const IconData pencil = Icons.edit;
  static const IconData eye = Icons.visibility;
  static const IconData eyeSlash = Icons.visibility_off;
  static const IconData chevronDown = Icons.keyboard_arrow_down;
  static const IconData chevronUp = Icons.keyboard_arrow_up;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData arrowPath = Icons.sync;
  static const IconData bolt = Icons.bolt;
  static const IconData bell = Icons.notifications;
  static const IconData language = Icons.language;
  static const IconData key = Icons.key;
  static const IconData identification = Icons.badge;
  static const IconData devicePhoneMobile = Icons.smartphone;
  static const IconData signal = Icons.signal_cellular_alt;
  static const IconData arrowDownTray = Icons.download;
  static const IconData userPlus = Icons.person_add;
  static const IconData queueList = Icons.format_list_numbered;
  static const IconData informationCircle = Icons.info;
  static const IconData inbox = Icons.inbox;

  // MDI placeholders
  static const IconData paw = Icons.pets;
  static const IconData wifi = Icons.wifi;
  static const IconData palette = Icons.palette;
  static const IconData shieldCheck = Icons.verified_user;
  static const IconData safe = Icons.lock;
  static const IconData paperclip = Icons.attach_file;
  static const IconData tagOutline = Icons.label_outlined;
  static const IconData clockOutline = Icons.access_time_outlined;
  static const IconData alertCircleOutline = Icons.error_outline;
  static const IconData asterisk = Icons.emergency;
  static const IconData dotsHorizontal = Icons.more_horiz;

  /// Resolves a semantic [name] to its placeholder [IconData].
  ///
  /// Returns `null` if the name is not recognized.
  static IconData? resolve(String name) {
    return switch (name) {
      'plus' => plus,
      'arrowLeft' => arrowLeft,
      'arrowRight' => arrowRight,
      'ellipsisVertical' => ellipsisVertical,
      'check' => check,
      'checkCircle' => checkCircle,
      'archiveBox' => archiveBox,
      'archiveBoxArrowDown' => archiveBoxArrowDown,
      'banknotes' => banknotes,
      'receiptPercent' => receiptPercent,
      'shoppingCart' => shoppingCart,
      'userCircle' => userCircle,
      'userGroup' => userGroup,
      'home' => home,
      'cog6Tooth' => cog6Tooth,
      'calendarDays' => calendarDays,
      'chartBar' => chartBar,
      'clipboardDocumentList' => clipboardDocumentList,
      'xMark' => xMark,
      'magnifyingGlass' => magnifyingGlass,
      'funnel' => funnel,
      'squares2x2' => squares2x2,
      'listBullet' => listBullet,
      'share' => share,
      'exclamationTriangle' => exclamationTriangle,
      'trash' => trash,
      'pencil' => pencil,
      'eye' => eye,
      'eyeSlash' => eyeSlash,
      'chevronDown' => chevronDown,
      'chevronUp' => chevronUp,
      'chevronRight' => chevronRight,
      'arrowPath' => arrowPath,
      'bolt' => bolt,
      'bell' => bell,
      'language' => language,
      'key' => key,
      'identification' => identification,
      'devicePhoneMobile' => devicePhoneMobile,
      'signal' => signal,
      'arrowDownTray' => arrowDownTray,
      'userPlus' => userPlus,
      'queueList' => queueList,
      'informationCircle' => informationCircle,
      'inbox' => inbox,
      'paw' => paw,
      'wifi' => wifi,
      'palette' => palette,
      'shieldCheck' => shieldCheck,
      'safe' => safe,
      'paperclip' => paperclip,
      'tagOutline' => tagOutline,
      'clockOutline' => clockOutline,
      'alertCircleOutline' => alertCircleOutline,
      'asterisk' => asterisk,
      'dotsHorizontal' => dotsHorizontal,
      _ => null,
    };
  }
}
