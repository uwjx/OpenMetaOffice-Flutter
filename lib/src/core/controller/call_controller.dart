// import 'package:flutter_ion/flutter_ion.dart';
// import 'package:flutter_ion/src/_library/apps/biz/proto/biz.pbenum.dart';
// import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
// import 'package:flutter_webrtc/src/helper.dart';
// import 'package:get/get.dart';
// import 'package:grpc/grpc.dart' as grpc;
// import 'package:openim_enterprise_chat/src/core/rtc/config.dart';
// import 'package:openim_enterprise_chat/src/core/rtc/participant.dart';
// import 'package:openim_enterprise_chat/src/routes/app_navigator.dart';
// import 'package:openim_enterprise_chat/src/utils/countdown.dart';
// import 'package:openim_enterprise_chat/src/utils/im_util.dart';
// import 'package:openim_enterprise_chat/src/widgets/call_view.dart';
//
// enum CallState {
//   CALL, // 主动邀请
//   CALLED, // 被邀请
//   REJECT, // 拒绝
//   BE_REJECTED, // 被拒绝
//   CALLING, // 通话中
//   HANGUP, // 挂断
//   BE_HANGUP, // 被挂断
//   CONNECTING,
//   NO_REPLY, // 无响应
//   CANCEL, // 取消
//   BE_CANCELED, // 被取消
// }
//
// class CallController extends GetxController {
//   IonBaseConnector? _connector;
//   IonAppBiz? _biz;
//   IonSDKSFU? _sfu;
//   var _heartFlag = true;
//   var streamType = StreamType.Voice;
//   var sessionType = SessionType.Single;
//   Participant? localStream;
//   var remoteStreams = <Participant>[].obs;
//
//   var _streamIdMappingUid = <String, String>{};
//   var _streamIdMappingStream = <String, Participant>{};
//   var uidMappingStream = <String, Participant>{};
//   var uidMappingPeer = <String, Peer>{};
//   Function(String uid, Participant? par)? onStreamChanged;
//   Function(String uid, Peer? peer)? onPeerChanged;
//
//   CallState? state;
//
//   // var stateSubject = PublishSubject<CallState>(); //.seeded(CallState.CALLING);
//   Function(CallState state)? onStateChanged;
//   late String uid;
//   late String token;
//   late String rid;
//   String gid = "";
//   late String receiveUid;
//   late String senderUid;
//   var receiverUidList = <String>[];
//   var speakerEnabled = true.obs;
//   var localVoiceEnabled = true.obs;
//   var localVideoEnabled = true.obs;
//
//   // var _initializedMic = false;
//   // var _initializedSpeaker = false;
//   var callingTime = "00:00:00".obs;
//   var callingDuration = 0;
//
//   CountdownTimer? _heartTimer;
//   CountdownTimer? _dialDurationTimer;
//   CountdownTimer? _callingTimer;
//
//   var localStreamCreated = false.obs;
//   ///占线
//   var _isBusy = false;
//   var _isLogin = false;
//
//   @override
//   onInit() {
//     _initRtc();
//     super.onInit();
//   }
//
//   @override
//   void onClose() {
//     close();
//     super.onClose();
//   }
//
//   void _stateChanged(CallState state) {
//     this.state = state;
//     onStateChanged?.call(state);
//     if (state == CallState.CALLING) {
//       _startCallingTimer();
//     }
//   }
//
//   void _streamChanged(String? uid, Participant? part) {
//     if (uid != null) {
//       if (null == part) {
//         uidMappingStream.remove(uid);
//       } else {
//         uidMappingStream.addAll({uid: part});
//       }
//       onStreamChanged?.call(uid, part);
//     }
//   }
//
//   void _peerChanged(String uid, Peer? peer) {
//     if (null == peer) {
//       uidMappingPeer.remove(uid);
//     } else {
//       uidMappingPeer.addAll({uid: peer});
//     }
//     onPeerChanged?.call(uid, peer);
//   }
//
//   void _addSteam(String streamId, Participant part) {
//     _streamIdMappingStream[streamId] = part;
//     var uid = _streamIdMappingUid[streamId];
//     if (uid != null) _streamChanged(uid, part);
//   }
//
//   _initRtc() async {
//     print('-----------init rtc---------------');
//     _connector ??= IonBaseConnector(
//       RtcConfig.ionClusterUrl,
//       token: 'token123123123',
//     );
//     _biz = IonAppBiz(_connector!);
//     _sfu = IonSDKSFU(_connector!);
//
//     _connector?.onclose = (IonService sev, grpc.GrpcError? err) {
//       print("Grpc close+++++++++++++ $sev  $err");
//       if (sev.name == 'biz' && err != null && err.codeName == "UNAVAILABLE") {
//         // _recon();
//       }
//     };
//
//     _biz?.onHeart = (String uid) {
//       print("+++++++++++++biz onHeart $uid");
//       _heartFlag = true;
//     };
//
//     _biz?.onMediaReply = (success, reason, errCode) {
//       print("+++++++++onMediaReply $success  $reason  $errCode");
//     };
//
//     _sfu?.ontrack = (track, RemoteStream remoteStream) async {
//       var streamId = remoteStream.id;
//       print('-----------远程推流---------onTrack: remote stream => $streamId');
//       var part = Participant(remoteStream, true)
//         ..initialize(speakerEnabled: speakerEnabled.value);
//       if (streamType == StreamType.Video) {
//         if (track.kind == "video") {
//           remoteStreams.add(part);
//           _addSteam(streamId, part);
//           _stateChanged(CallState.CALLING);
//           // _startCallingTimer();
//         }
//       } else {
//         remoteStreams.add(part);
//         _addSteam(streamId, part);
//         _stateChanged(CallState.CALLING);
//         // _startCallingTimer();
//       }
//     };
//
//     _biz?.onJoin = (bool success, String reason) async {
//       print('---------biz onJoin success = $success, reason = $reason');
//
//       if (success) {
//         await _sfu?.connect();
//         await _sfu?.join(rid, uid);
//
//         print('-----------本地推流------------0------');
//         var localS = await LocalStream.getUserMedia(
//             constraints: RtcConfig.defaultConstraints
//               ..video = (streamType == StreamType.Video));
//         print('-----------本地推流------------1------');
//         await _sfu?.publish(localS);
//
//         print('-----------本地推流----------2--------');
//         localStream = Participant(localS, false)
//           ..initialize(voiceEnabled: localVoiceEnabled.value);
//
//         localStreamCreated.value = true;
//
//         _addSteam(uid, localStream!);
//
//         if (sessionType == SessionType.Group) {
//           _stateChanged(CallState.CALLING);
//           // _startCallingTimer();
//         }
//         // _stateChanged(CallState.CALLING);
//       }
//     };
//
//     _biz?.onMediaHandle = (MediaEvent event) async {
//       print('-----------------onMediaHandle-----${event.so}---------');
//       var so = event.so;
//       senderUid = event.senderUid;
//       receiveUid = event.receiverUid;
//       gid = event.groupID;
//       streamType = event.streamType;
//       sessionType = event.sessionType;
//       switch (so) {
//         case MediaOperation.Dial:
//           {
//             if (_isBusy) return;
//             _isBusy = true;
//             _stateChanged(CallState.CALLED);
//             if (event.sessionType == SessionType.Single) {
//               var list = await OpenIM.iMManager.getUsersInfo([senderUid]);
//               IMCallView.call(
//                 uid: senderUid,
//                 name: list[0].getShowName(),
//                 icon: list[0].icon,
//                 state: CallState.CALLED,
//                 type: streamType == StreamType.Voice ? 'voice' : 'video',
//               );
//             } else {
//               AppNavigator.startGroupCall(
//                 gid: gid,
//                 senderUid: senderUid,
//                 receiverIds: [],
//                 type: streamType == StreamType.Voice ? 'voice' : 'video',
//                 state: CallState.CALLED,
//               );
//             }
//           }
//           break;
//         case MediaOperation.Accept:
//           {
//             _dialDurationTimer?.cancel();
//             _stateChanged(CallState.CONNECTING);
//             _biz?.join(
//               sid: rid = receiveUid + senderUid,
//               uid: uid,
//               info: {
//                 "name": OpenIM.iMManager.uInfo.getShowName(),
//                 "icon": OpenIM.iMManager.uInfo.icon,
//               },
//             );
//           }
//           break;
//         case MediaOperation.Refuse:
//           {
//             _dialDurationTimer?.cancel();
//             _stateChanged(CallState.BE_REJECTED);
//           }
//           break;
//         case MediaOperation.Cancel:
//           {
//             if (event.sessionType == SessionType.Single) {
//               if (state == CallState.CONNECTING) close();
//               _stateChanged(CallState.BE_CANCELED);
//             }
//           }
//           break;
//         case MediaOperation.HangUp:
//           // _changedState(CallState.BE_HANGUP);
//           // app意外退出，对方收不到这个事件，通过peer事件判断
//           break;
//         default:
//       }
//     };
//
//     _biz?.onLoginHandle = (bool success, String reason, String uid) {
//       _heart();
//       if (success) _heartFlag = true;
//     };
//
//     _biz?.onStreamEvent = (StreamEvent event) {
//       var streamId = event.streams[0].id;
//       var uid = event.uid;
//       _streamIdMappingUid[streamId] = uid;
//       switch (event.state) {
//         case StreamState.NONE:
//           break;
//         case StreamState.ADD:
//           {
//             // if (remoteStreams.isNotEmpty && event.streams.isNotEmpty) {
//             // }
//             var part = _streamIdMappingStream[streamId];
//             if (null != part) {
//               _streamChanged(uid, part);
//             }
//           }
//           break;
//         case StreamState.REMOVE:
//           {
//             _streamChanged(uid, null);
//             if (sessionType == SessionType.Group) {
//               print('StreamEvent ID::::' + streamId);
//               remoteStreams.removeWhere((e) => e.id == streamId);
//               remoteStreams.refresh();
//               // _changedState(CallState.CALLING);
//             }
//           }
//           break;
//       }
//       print(
//           'onStreamEvent state = ${event.state}, sid = ${event.sid}, uid = ${event.uid},  streams = ${event.streams.toString()}');
//     };
//
//     _biz?.onPeerEvent = (PeerEvent event) {
//       var uid = event.peer.uid;
//       switch (event.state) {
//         case PeerState.NONE:
//           break;
//         case PeerState.JOIN:
//           _peerChanged(uid, event.peer);
//           break;
//         case PeerState.UPDATE:
//           break;
//         case PeerState.LEAVE:
//           {
//             _peerChanged(uid, null);
//             if (sessionType == SessionType.Single) {
//               close();
//               _stateChanged(CallState.BE_HANGUP);
//             }
//           }
//           break;
//       }
//       print(
//           'onPeerEvent state = ${event.state}, uid = $uid, info = ${event.peer.info.toString()}');
//     };
//
//     await _biz?.connect();
//   }
//
//   void mediaHandle(
//     MediaOperation operation,
//     List<String> receiverIds,
//     StreamType streamType,
//     SessionType sessionType,
//   ) {
//     print("========mediaHandle======$operation===========$streamType");
//     if (_biz == null) return;
//     this.streamType = streamType;
//     this.sessionType = sessionType;
//     this.receiverUidList = receiverIds;
//     var info = {
//       "name": OpenIM.iMManager.uInfo.getShowName(),
//       "icon": OpenIM.iMManager.uInfo.icon,
//     };
//     switch (operation) {
//       case MediaOperation.Dial:
//         {
//           if (sessionType == SessionType.Single) {
//             _stateChanged(CallState.CALL);
//             _startDialTimer();
//           } else {
//             _biz?.join(sid: rid = uid + gid, uid: uid, info: info);
//           }
//         }
//         break;
//       case MediaOperation.Accept:
//         {
//           _stateChanged(CallState.CONNECTING);
//           _biz?.join(
//             sid: rid = (sessionType == SessionType.Single)
//                 ? (senderUid + receiveUid)
//                 : (senderUid + gid),
//             uid: uid,
//             info: info,
//           );
//         }
//         break;
//       case MediaOperation.Refuse:
//         {
//           _stateChanged(CallState.REJECT);
//         }
//         break;
//       case MediaOperation.Cancel:
//         {
//           _dialDurationTimer?.cancel();
//           _stateChanged(CallState.CANCEL);
//         }
//         break;
//       case MediaOperation.HangUp:
//         {
//           close();
//           _stateChanged(CallState.HANGUP);
//         }
//         break;
//       default:
//     }
//     if (sessionType == SessionType.Group &&
//         operation != MediaOperation.Dial &&
//         operation != MediaOperation.Cancel) return;
//     // group - dial, cancel
//     _bizMediaHandle(operation);
//   }
//
//   _bizMediaHandle(MediaOperation op) {
//     _biz?.mediaHandle(
//         op, uid, token, receiverUidList, 1, 1, streamType, sessionType, gid);
//   }
//
//   void close() {
//     // _initializedMic = false;
//     // _initializedSpeaker = false;
//     _isBusy = false;
//     speakerEnabled.value = true;
//     localVoiceEnabled.value = true;
//     localVideoEnabled.value = true;
//     localStreamCreated.value = false;
//     callingTime.value = "00:00:00";
//     callingDuration = 0;
//     _dialDurationTimer?.cancel();
//     _callingTimer?.cancel();
//     // _heartTimer?.cancel();
//     // _heartTimer = null;
//     _dialDurationTimer = null;
//     _callingTimer = null;
//     _biz?.leave(uid);
//     try {
//       _sfu?.close();
//     } catch (e) {
//       e.printError();
//     }
//     try {
//       remoteStreams.forEach((element) {
//         element.dispose();
//       });
//       remoteStreams.clear();
//       localStream?.dispose();
//       localStream = null;
//     } catch (e) {
//       e.printError();
//     }
//   }
//
//   void _recon() async {
//     print('-----------重连---------------');
//     _biz?.close();
//     // if (state == CallState.CALLING || state == CallState.CONNECTING) {
//     //
//     // }
//     try {
//       _sfu?.close();
//     } catch (e) {
//       e.printError();
//     }
//     _connector?.close();
//     _connector = null;
//     _biz = null;
//     _sfu = null;
//     // _initializedMic = false;
//     // _initializedSpeaker = false;
//     await _initRtc();
//     login(uid, token);
//   }
//
//   /// 每隔30s发送一次心跳包
//   void _heart() {
//     _heartTimer?.cancel();
//     _heartTimer = CountdownTimer.periodic(
//       Duration(seconds: 5),
//       (timer, count) {
//         if (OpenIM.iMManager.isLogined) {
//           _biz?.heart(uid);
//           if (_heartFlag) {
//             _heartFlag = false;
//           } else {
//             _recon();
//           }
//         }
//       },
//     );
//   }
//
//   void _startDialTimer() {
//     // 45sm没人接听取消拨号
//     _dialDurationTimer?.cancel();
//     _dialDurationTimer = CountdownTimer(45, onFinished: () {
//       // state = CallState.CANCEL;
//       _bizMediaHandle(MediaOperation.Cancel);
//       _stateChanged(CallState.CANCEL);
//     });
//   }
//
//   void _startCallingTimer() {
//     if (null == _callingTimer) {
//       _callingTimer = CountdownTimer.periodic(
//         Duration(seconds: 1),
//         (timer, count) {
//           callingTime.value = IMUtil.seconds2HMS(callingDuration = count);
//         },
//       );
//     }
//   }
//
//   login(String uid, String token) async {
//     this.uid = uid;
//     this.token = token;
//     _biz?.loginHandle(LoginHandle_Operation.Login, uid, token, 1);
//   }
//
//   logout() async {
//     _heartTimer?.cancel();
//     _heartTimer = null;
//     _biz?.loginHandle(LoginHandle_Operation.LoginOut, uid, token, 1);
//   }
//
//   void switchCamera() {
//     if (null != localStream) {
//       if (localStream!.renderer.srcObject!.getAudioTracks().length > 0) {
//         Helper.switchCamera(
//             localStream!.renderer.srcObject!.getVideoTracks()[0]);
//       }
//     }
//   }
//
//   // void _initSpeaker() {
//   //   if (!_initializedSpeaker) {
//   //     _initializedSpeaker = true;
//   //     remoteStreams[0]
//   //         .renderer
//   //         .srcObject!
//   //         .getAudioTracks()[0]
//   //         .enableSpeakerphone(speakerEnabled.value);
//   //   }
//   // }
//   //
//   // void _initMic() {
//   //   if (!_initializedMic) {
//   //     _initializedMic = true;
//   //     localStream!.renderer.srcObject!
//   //         .getAudioTracks()[0]
//   //         .setMicrophoneMute(localVoiceEnabled.value);
//   //   }
//   // }
//
//   void toggleSpeaker() {
//     speakerEnabled.value = !speakerEnabled.value;
//     print('============speakerEnabled${speakerEnabled.value}========');
//     if (remoteStreams.isNotEmpty) {
//       remoteStreams[0]
//           .renderer
//           .srcObject!
//           .getAudioTracks()[0]
//           .enableSpeakerphone(speakerEnabled.value);
//     }
//   }
//
//   void toggleMuteLocal() {
//     localVoiceEnabled.value = !localVoiceEnabled.value;
//     print('============localVoiceEnabled${localVoiceEnabled.value}========');
//     if (null != localStream) {
//       localStream!.renderer.srcObject!
//           .getAudioTracks()[0]
//           .setMicrophoneMute(localVoiceEnabled.value);
//     }
//   }
//
//   void trackControl() {
//     localVideoEnabled.value = !localVideoEnabled.value;
//     if (null != localStream) {
//       localStream!.renderer.srcObject!.getVideoTracks()[0].enabled =
//           localVideoEnabled.value;
//     }
//   }
// }
