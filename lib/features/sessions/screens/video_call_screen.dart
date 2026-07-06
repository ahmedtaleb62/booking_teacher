import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

/// Thin wrapper around the native Jitsi Meet SDK.
/// Opens Jitsi natively — no WebView, no pre-join screen, no JS hacks.
class VideoCallService {
  static final _jitsi = JitsiMeet();

  /// Room name derived deterministically from the session ID.
  static String roomName(String sessionId) =>
      'HajezUstad${sessionId.replaceAll('-', '').substring(0, 12)}';

  static Future<void> join({
    required String sessionId,
    required String displayName,
    String? avatarUrl,
    String languageCode = 'ar',
    VoidCallback? onTerminated,
    VoidCallback? onParticipantJoined,
    void Function(String error)? onError,
  }) async {
    final options = JitsiMeetConferenceOptions(
      serverURL: 'https://meet.ffmuc.net',
      room: roomName(sessionId),
      userInfo: JitsiMeetUserInfo(
        displayName: displayName.isNotEmpty ? displayName : 'مستخدم',
        avatar: avatarUrl,
      ),
      featureFlags: {
        FeatureFlags.inviteEnabled:        false,
        FeatureFlags.recordingEnabled:     false,
        FeatureFlags.liveStreamingEnabled: false,
        FeatureFlags.meetingNameEnabled:   false,
        FeatureFlags.kickOutEnabled:       false,
        FeatureFlags.toolboxAlwaysVisible: true,
        'prejoinpage.enabled':             false,
        'lobby-mode.enabled':              false,
        'ios.screensharing.enabled':       false,
        'chat.enabled':                    false,
        'participants-pane.enabled':       false,
        'overflow-menu.enabled':           false,
      },
      configOverrides: {
        'startWithAudioMuted':       false,
        'startWithVideoMuted':       false,
        'disableDeepLinking':        true,
        'lobby.enabled':             false,
        'enableLobbyChat':           false,
        'defaultLanguage':           languageCode,
        'enableNoisyMicDetection':   false,
        'disableAP':                 false,
      },
    );

    await _jitsi.join(
      options,
      JitsiMeetEventListener(
        conferenceTerminated: (url, error) {
          if (error != null) {
            onError?.call(error.toString());
          }
          onTerminated?.call();
        },
        conferenceJoined:  (url) => debugPrint('[Jitsi] Joined: $url'),
        participantJoined: (email, name, role, id) {
          debugPrint('[Jitsi] Participant joined: $name');
          onParticipantJoined?.call();
        },
      ),
    );
  }

  static Future<void> hangUp() async {
    await _jitsi.hangUp();
  }
}
