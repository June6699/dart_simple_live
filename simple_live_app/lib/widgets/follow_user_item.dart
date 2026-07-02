import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/widgets/net_image.dart';

enum FollowUserItemStyle {
  defaultList,
  compactList,
  card,
}

class FollowUserItem extends StatelessWidget {
  final FollowUser item;
  final Function()? onRemove;
  final Function()? onSpecialTap;
  final Function()? onTap;
  final Function()? onLongPress;
  final bool playing;
  final bool showSpecialMark;
  final bool showLiveCover;
  final FollowUserItemStyle style;

  const FollowUserItem({
    required this.item,
    this.onRemove,
    this.onSpecialTap,
    this.onTap,
    this.onLongPress,
    this.playing = false,
    this.showSpecialMark = false,
    this.showLiveCover = false,
    this.style = FollowUserItemStyle.defaultList,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (style) {
        case FollowUserItemStyle.compactList:
          return _buildListCard(context, compact: true);
        case FollowUserItemStyle.card:
          return _buildPreviewCard(context);
        case FollowUserItemStyle.defaultList:
          return _buildListCard(context, compact: false);
      }
    });
  }

  Widget _buildListCard(BuildContext context, {required bool compact}) {
    if (!showLiveCover) {
      return _buildAvatarListCard(context, compact: compact);
    }
    final theme = Theme.of(context);
    final coverWidth = compact ? 118.0 : 148.0;
    final avatarSize = compact ? 38.0 : 46.0;
    final radius = BorderRadius.circular(compact ? 14 : 16);
    final titleStyle = compact
        ? theme.textTheme.titleSmall
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade600,
    );
    return Material(
      color: theme.cardColor,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: playing
                  ? theme.colorScheme.primary.withAlpha(180)
                  : Colors.black.withAlpha(20),
              width: playing ? 1.4 : 0.8,
            ),
            borderRadius: radius,
          ),
          padding: EdgeInsets.all(compact ? 8 : 10),
          child: Row(
            children: [
              SizedBox(
                width: coverWidth,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildCover(context, radius: compact ? 12 : 14),
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: SizedBox.expand(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NetImage(
                            item.face,
                            width: avatarSize,
                            height: avatarSize,
                            borderRadius: avatarSize / 2,
                          ),
                          SizedBox(width: compact ? 8 : 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    text: item.userName,
                                    children: [
                                      WidgetSpan(
                                        alignment:
                                            ui.PlaceholderAlignment.middle,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: _buildStatusDot(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                                SizedBox(height: compact ? 4 : 6),
                                Text(
                                  _displayRoomTitle(),
                                  maxLines: compact ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: compact ? 6 : 8),
                          _buildActionArea(
                            context,
                            compact: compact,
                            vertical: true,
                          ),
                        ],
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Image.asset(
                            _site.logo,
                            width: compact ? 16 : 18,
                            height: compact ? 16 : 18,
                          ),
                          Text(
                            _site.name,
                            style: subtitleStyle,
                          ),
                          _buildInfoChip(
                            context,
                            label: getStatus(item.liveStatus.value),
                            active: item.liveStatus.value == 2,
                          ),
                          if (_liveDurationText().isNotEmpty)
                            Text(
                              _liveDurationText(),
                              style: subtitleStyle,
                            ),
                          if (playing)
                            Text(
                              "正在观看",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (showSpecialMark && item.isSpecialFollow)
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarListCard(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    final avatarSize = compact ? 48.0 : 58.0;
    final radius = BorderRadius.circular(compact ? 12 : 14);
    final titleStyle = compact
        ? theme.textTheme.titleSmall
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade600,
    );
    return Material(
      color: theme.cardColor,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: playing
                  ? theme.colorScheme.primary.withAlpha(180)
                  : Colors.black.withAlpha(16),
              width: playing ? 1.4 : 0.6,
            ),
            borderRadius: radius,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            children: [
              NetImage(
                item.face,
                width: avatarSize,
                height: avatarSize,
                borderRadius: avatarSize / 2,
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusDot(),
                        const SizedBox(width: 4),
                        Text(
                          getStatus(item.liveStatus.value),
                          style: subtitleStyle,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Row(
                      children: [
                        Image.asset(
                          _site.logo,
                          width: compact ? 16 : 18,
                          height: compact ? 16 : 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _site.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: subtitleStyle,
                          ),
                        ),
                        if (_liveDurationText().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _liveDurationText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: subtitleStyle,
                            ),
                          ),
                        ],
                        if (playing) ...[
                          const SizedBox(width: 8),
                          Text(
                            "正在观看",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 6 : 10),
              _buildActionArea(
                context,
                compact: compact,
                vertical: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    if (!showLiveCover) {
      return _buildAvatarCard(context);
    }
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(16);
    return Material(
      color: theme.cardColor,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: playing
                  ? theme.colorScheme.primary.withAlpha(180)
                  : Colors.black.withAlpha(24),
              width: playing ? 1.4 : 0.8,
            ),
            borderRadius: radius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildCover(context, radius: 0),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NetImage(
                        item.face,
                        width: 42,
                        height: 42,
                        borderRadius: 21,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _displayRoomTitle(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const Spacer(),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Image.asset(
                                  _site.logo,
                                  width: 16,
                                  height: 16,
                                ),
                                Text(
                                  _site.name,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                _buildInfoChip(
                                  context,
                                  label: getStatus(item.liveStatus.value),
                                  active: item.liveStatus.value == 2,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildActionArea(
                        context,
                        compact: true,
                        vertical: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCard(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(16);
    return Material(
      color: theme.cardColor,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: playing
                  ? theme.colorScheme.primary.withAlpha(180)
                  : Colors.black.withAlpha(24),
              width: playing ? 1.4 : 0.8,
            ),
            borderRadius: radius,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NetImage(
                item.face,
                width: 72,
                height: 72,
                borderRadius: 36,
              ),
              const SizedBox(height: 12),
              Text(
                item.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Image.asset(_site.logo, width: 16, height: 16),
                  Text(
                    _site.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  _buildInfoChip(
                    context,
                    label: getStatus(item.liveStatus.value),
                    active: item.liveStatus.value == 2,
                  ),
                  if (playing)
                    _buildInfoChip(
                      context,
                      label: "正在观看",
                      active: true,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _buildActionArea(
                context,
                compact: true,
                vertical: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context, {required double radius}) {
    final theme = Theme.of(context);
    if (item.liveStatus.value != 2) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Text(
          "未直播",
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final coverImage = _coverImage;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: coverImage.isEmpty
              ? Center(
                  child: Text(
                    "直播封面补齐中",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                )
              : NetImage(
                  coverImage,
                  fit: BoxFit.cover,
                  borderRadius: radius,
                ),
        ),
        Positioned(
          left: 8,
          top: 8,
          child: _buildInfoChip(
            context,
            label: getStatus(item.liveStatus.value),
            active: item.liveStatus.value == 2,
          ),
        ),
        if (playing)
          Positioned(
            right: 8,
            top: 8,
            child: _buildInfoChip(
              context,
              label: "正在观看",
              active: true,
            ),
          ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Text(
            _displayRoomTitle(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  blurRadius: 8,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDot() {
    final active = item.liveStatus.value == 2;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required String label,
    required bool active,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.primary.withAlpha(28)
            : Colors.black.withAlpha(20),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: active ? theme.colorScheme.primary : Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionArea(
    BuildContext context, {
    required bool compact,
    required bool vertical,
  }) {
    final iconSize = compact ? 18.0 : 20.0;
    final children = <Widget>[
      if (onSpecialTap != null)
        IconButton(
          tooltip: item.isSpecialFollow ? "取消特别关注" : "特别关注",
          iconSize: iconSize,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: onSpecialTap,
          icon: Icon(
            item.isSpecialFollow ? Icons.star : Icons.star_border,
            color: item.isSpecialFollow ? Colors.amber : null,
          ),
        )
      else if (showSpecialMark && item.isSpecialFollow)
        Icon(
          Icons.star,
          color: Colors.amber,
          size: iconSize,
        ),
      if (onRemove != null)
        IconButton(
          iconSize: iconSize,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: onRemove,
          icon: const Icon(Remix.dislike_line),
        ),
    ];
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: children,
          );
  }

  Site get _site => Sites.allSites[item.siteId]!;

  String get _coverImage {
    if (item.liveStatus.value != 2) {
      return "";
    }
    return item.roomCover.trim();
  }

  String _displayRoomTitle() {
    final title = item.roomTitle.trim();
    if (item.liveStatus.value == 2) {
      if (title.isNotEmpty) {
        return title;
      }
      return showLiveCover ? "直播封面与标题补齐中" : item.userName;
    }
    return item.userName;
  }

  String getStatus(int status) {
    if (status == 2) {
      return "直播中";
    }
    if (status == 0) {
      return "未确认";
    }
    return "未开播";
  }

  String _liveDurationText() {
    final duration = formatLiveDuration(item.liveStartTime);
    if (duration.isEmpty) {
      return "";
    }
    return "开播 $duration";
  }

  String formatLiveDuration(String? startTimeStampString) {
    if (startTimeStampString == null ||
        startTimeStampString.isEmpty ||
        startTimeStampString == "0") {
      return "";
    }
    try {
      final startTimeStamp = int.parse(startTimeStampString);
      final currentTimeStamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final durationInSeconds = currentTimeStamp - startTimeStamp;
      final hours = durationInSeconds ~/ 3600;
      final minutes = (durationInSeconds % 3600) ~/ 60;
      final hourText = hours > 0 ? '$hours小时' : '';
      final minuteText = minutes > 0 ? '$minutes分钟' : '';
      if (hours == 0 && minutes == 0) {
        return "不足1分钟";
      }
      return '$hourText$minuteText';
    } catch (e) {
      Log.logPrint('格式化开播时长出错: $e');
      return "";
    }
  }
}
