import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import 'crash_buffer.dart';

enum IssueReportStatus { sent, shared, cancelled, failed }

/// Builds and sends a user-initiated issue report via the user's email app.
abstract final class IssueReport {
  static Future<String> buildBody({
    required String userMessage,
    bool includeCrash = true,
    PackageInfo? packageInfo,
  }) async {
    final info = packageInfo ?? await PackageInfo.fromPlatform();
    final crash = includeCrash ? await CrashBuffer.latest() : null;
    final buffer = StringBuffer()
      ..writeln('${AppBrand.name} issue report')
      ..writeln('App version: ${info.version} (${info.buildNumber})')
      ..writeln('Platform: ${describePlatform()}')
      ..writeln()
      ..writeln('What happened:')
      ..writeln(userMessage.trim().isEmpty ? '(not provided)' : userMessage.trim());

    if (crash != null) {
      buffer
        ..writeln()
        ..writeln('--- Last crash (on this device) ---')
        ..writeln(crash.format());
    }

    buffer
      ..writeln()
      ..writeln('---')
      ..writeln(
        'No spending history or SMS content is included unless you add it above.',
      );

    return buffer.toString();
  }

  static String describePlatform() {
    if (kIsWeb) return 'Web';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }

  static Future<IssueReportStatus> send({
    required String userMessage,
    bool includeCrash = true,
  }) async {
    final body = await buildBody(
      userMessage: userMessage,
      includeCrash: includeCrash,
    );
    final subject = '${AppBrand.name} issue report';
    final mailUri = Uri(
      scheme: 'mailto',
      path: AppBrand.supportEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    if (await canLaunchUrl(mailUri)) {
      final opened = await launchUrl(
        mailUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) {
        if (includeCrash) await CrashBuffer.clear();
        return IssueReportStatus.sent;
      }
    }

    await Share.share(body, subject: subject);
    if (includeCrash) await CrashBuffer.clear();
    return IssueReportStatus.shared;
  }

  static Future<void> openSheet(BuildContext context) async {
    HapticFeedback.lightImpact();
    final crash = await CrashBuffer.latest();
    if (!context.mounted) return;

    final result = await showModalBottomSheet<IssueReportStatus>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IssueReportSheet(hasCrash: crash != null),
    );

    if (!context.mounted || result == null) return;
    final message = switch (result) {
      IssueReportStatus.sent => 'Email app opened — send when ready',
      IssueReportStatus.shared => 'Choose how to send your report',
      IssueReportStatus.failed => 'Could not open report — try again',
      IssueReportStatus.cancelled => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

class _IssueReportSheet extends StatefulWidget {
  const _IssueReportSheet({required this.hasCrash});

  final bool hasCrash;

  @override
  State<_IssueReportSheet> createState() => _IssueReportSheetState();
}

class _IssueReportSheetState extends State<_IssueReportSheet> {
  final _controller = TextEditingController();
  var _includeCrash = true;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _includeCrash = widget.hasCrash;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final status = await IssueReport.send(
        userMessage: _controller.text,
        includeCrash: _includeCrash && widget.hasCrash,
      );
      if (!mounted) return;
      Navigator.of(context).pop(status);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(IssueReportStatus.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: const Color(0xFF1A1010),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Report an issue',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Opens your email app addressed to ${AppBrand.supportEmail}. '
                  'Nothing is sent until you tap Send in your mail app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'What went wrong? Steps to reproduce…',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (widget.hasCrash) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include last crash details'),
                    subtitle: const Text(
                      'Technical error info from this device only',
                    ),
                    value: _includeCrash,
                    onChanged: _sending
                        ? null
                        : (v) => setState(() => _includeCrash = v),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mail_outline_rounded),
                  label: Text(_sending ? 'Opening…' : 'Send report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
