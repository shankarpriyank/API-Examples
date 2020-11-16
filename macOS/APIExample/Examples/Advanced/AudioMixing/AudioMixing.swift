//
//  JoinChannelVC.swift
//  APIExample
//
//  Created by 张乾泽 on 2020/4/17.
//  Copyright © 2020 Agora Corp. All rights reserved.
//
import Cocoa
import AgoraRtcKit
import AGEVideoLayout

class AudioMixing: BaseViewController {
    let EFFECT_ID:Int32 = 1
    let EFFECT_ID_2:Int32 = 2
    var videos: [VideoView] = []
    
    @IBOutlet weak var container: AGEVideoContainer!
    @IBOutlet weak var channelField: NSTextField!
    @IBOutlet weak var joinBtn: NSButton!
    @IBOutlet weak var leaveBtn: NSButton!
    @IBOutlet weak var micPicker: NSPopUpButton!
    @IBOutlet weak var profilePicker: NSPopUpButton!
    @IBOutlet weak var scenarioPicker: NSPopUpButton!
    @IBOutlet weak var layoutPicker: NSPopUpButton!
    @IBOutlet weak var startAudioMixingBtn: NSButton!
    @IBOutlet weak var pauseAudioMixingBtn: NSButton!
    @IBOutlet weak var resumeAudioMixingBtn: NSButton!
    @IBOutlet weak var stopAudioMixingBtn: NSButton!
    @IBOutlet weak var playAudioEffectBtn: NSButton!
    @IBOutlet weak var playAudioEffectBtn2: NSButton!
    @IBOutlet weak var pauseAudioEffectBtn: NSButton!
    @IBOutlet weak var resumeAudioEffectBtn: NSButton!
    @IBOutlet weak var stopAudioEffectBtn: NSButton!
    @IBOutlet weak var stopAudioEffectBtn2: NSButton!
    @IBOutlet weak var mixingVolumeSlider: NSSlider!
    @IBOutlet weak var mixingPlaybackVolumeSlider: NSSlider!
    @IBOutlet weak var mixingPublishVolumeSlider: NSSlider!
    @IBOutlet weak var effectVolumeSlider: NSSlider!
    @IBOutlet weak var effectVolumeSlider2: NSSlider!
    @IBOutlet weak var audioMixingProgress: NSProgressIndicator!
    @IBOutlet weak var audioMixingDuration: NSTextField!
    
    var agoraKit: AgoraRtcEngineKit!
    var timer:Timer?
    var mics:[AgoraRtcDeviceInfo] = [] {
        didSet {
            DispatchQueue.main.async {[unowned self] in
                self.micPicker.addItems(withTitles: self.mics.map({ (device: AgoraRtcDeviceInfo) -> String in
                    return (device.deviceName ?? "")
                }))
            }
        }
    }
    var scenarios:[AgoraAudioScenario] = [] {
        didSet {
            DispatchQueue.main.async {[unowned self] in
                self.scenarioPicker.addItems(withTitles: self.scenarios.map({ (scenario: AgoraAudioScenario) -> String in
                    return scenario.description()
                }))
            }
        }
    }
    var profiles:[AgoraAudioProfile] = [] {
        didSet {
            DispatchQueue.main.async {[unowned self] in
                self.profilePicker.addItems(withTitles: self.profiles.map({ (profile: AgoraAudioProfile) -> String in
                    return profile.description()
                }))
            }
        }
    }
    
    // indicate if current instance has joined channel
    var isJoined: Bool = false {
        didSet {
            channelField.isEnabled = !isJoined
            joinBtn.isHidden = isJoined
            leaveBtn.isHidden = !isJoined
            layoutPicker.isEnabled = !isJoined
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layoutVideos(2)
        
        profiles = AgoraAudioProfile.allValues()
        scenarios = AgoraAudioScenario.allValues()
        
        // set up agora instance when view loaded
        let config = AgoraRtcEngineConfig()
        config.appId = KeyCenter.AppId
        //config.areaCode = GlobalSettings.shared.area.rawValue
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        
        //find device in a separate thread to avoid blocking main thread
        let queue = DispatchQueue(label: "device.enumerateDevices")
        queue.async {[unowned self] in
            self.mics = self.agoraKit.enumerateDevices(.audioRecording) ?? []
        }
    }
    
    override func viewWillBeRemovedFromSplitView() {
        if(isJoined) {
            agoraKit.leaveChannel { (stats:AgoraChannelStats) in
                LogUtils.log(message: "Left channel", level: .info)
            }
        }
    }
    
    @IBAction func onJoinPressed(_ sender:Any) {
        // use selected devices
        if let micId = mics[micPicker.indexOfSelectedItem].deviceId {
            agoraKit.setDevice(.audioRecording, deviceId: micId)
        }
        
        // disable video module in audio scene
        agoraKit.disableVideo()
        let profile = profiles[profilePicker.indexOfSelectedItem]
        let scenario = scenarios[scenarioPicker.indexOfSelectedItem]
        agoraKit.setAudioProfile(profile, scenario: scenario)
        
        // set live broadcaster mode
        agoraKit.setChannelProfile(.liveBroadcasting)
        // set myself as broadcaster to stream audio
        agoraKit.setClientRole(.broadcaster)
        
        // enable volume indicator
        agoraKit.enableAudioVolumeIndication(200, smooth: 3)
        
        // update slider values
        mixingPlaybackVolumeSlider.doubleValue = Double(agoraKit.getAudioMixingPlayoutVolume())
        mixingPublishVolumeSlider.doubleValue = Double(agoraKit.getAudioMixingPublishVolume())
        effectVolumeSlider.doubleValue = Double(agoraKit.getEffectsVolume())
        effectVolumeSlider2.doubleValue = Double(agoraKit.getEffectsVolume())

        
        // start joining channel
        // 1. Users can only see each other after they join the
        // same channel successfully using the same app id.
        // 2. If app certificate is turned on at dashboard, token is needed
        // when joining channel. The channel name and uid used to calculate
        // the token has to match the ones used for channel join
        let result = agoraKit.joinChannel(byToken: nil, channelId: channelField.stringValue, info: nil, uid: 0) {[unowned self] (channel, uid, elapsed) -> Void in
            self.isJoined = true
            self.videos[0].uid = uid
            LogUtils.log(message: "Join \(channel) with uid \(uid) elapsed \(elapsed)ms", level: .info)
        }
        if result != 0 {
            // Usually happens with invalid parameters
            // Error code description can be found at:
            // en: https://docs.agora.io/en/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
            // cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
            self.showAlert(title: "Error", message: "joinChannel call failed: \(result), please check your params")
        }
    }
    
    @IBAction func onLeavePressed(_ sender: Any) {
        agoraKit.leaveChannel { [unowned self] (stats:AgoraChannelStats) in
            LogUtils.log(message: "Left channel", level: .info)
            self.videos[0].uid = nil
            self.isJoined = false
        }
    }
    
    @IBAction func onLayoutChanged(_ sender: NSPopUpButton) {
        switch(sender.indexOfSelectedItem) {
            //1x1
        case 0:
            layoutVideos(2)
            break
            //1x3
        case 1:
            layoutVideos(4)
            break
            //1x8
        case 2:
            layoutVideos(9)
            break
            //1x15
        case 3:
            layoutVideos(16)
            break
        default:
            layoutVideos(2)
        }
    }
    
    func startProgressTimer() {
        // begin timer to update progress
        if(timer == nil) {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self](timer:Timer) in
                guard let weakself = self else {return}
                let progress = Double(weakself.agoraKit.getAudioMixingCurrentPosition()) / Double(weakself.agoraKit.getAudioMixingDuration())
                weakself.audioMixingProgress.doubleValue = progress
            })
        }
    }
    
    func stopProgressTimer() {
        // stop timer
        if(timer != nil) {
            timer?.invalidate()
            timer = nil
        }
    }
    
    func updateTotalDuration(reset:Bool) {
        if(reset) {
            audioMixingDuration.stringValue = "00 : 00"
        } else {
            let duration = agoraKit.getAudioMixingDuration()
            let seconds = duration / 1000
            audioMixingDuration.stringValue = "\(String(format: "%02d", seconds / 60)) : \(String(format: "%02d", seconds % 60))"
        }
    }
    
    @IBAction func onStartAudioMixing(_ sender: NSButton) {
        if let filepath = Bundle.main.path(forResource: "audiomixing", ofType: "mp3") {
            let result = agoraKit.startAudioMixing(filepath, loopback: false, replace: false, cycle: -1)
            if result != 0 {
                self.showAlert(title: "Error", message: "startAudioMixing call failed: \(result), please check your params")
            } else {
                startProgressTimer()
                updateTotalDuration(reset: false)
            }
        }
    }
    
    @IBAction func onStopAudioMixing(_ sender:NSButton){
        let result = agoraKit.stopAudioMixing()
        if result != 0 {
            self.showAlert(title: "Error", message: "stopAudioMixing call failed: \(result), please check your params")
        } else {
            stopProgressTimer()
            updateTotalDuration(reset: true)
        }
    }
    
    @IBAction func onPauseAudioMixing(_ sender:NSButton){
        let result = agoraKit.pauseAudioMixing()
        if result != 0 {
            self.showAlert(title: "Error", message: "pauseAudioMixing call failed: \(result), please check your params")
        } else {
            stopProgressTimer()
        }
    }
    
    @IBAction func onResumeAudioMixing(_ sender:NSButton){
        let result = agoraKit.resumeAudioMixing()
        if result != 0 {
            self.showAlert(title: "Error", message: "resumeAudioMixing call failed: \(result), please check your params")
        } else {
            startProgressTimer()
        }
    }
    
    @IBAction func onAudioMixingVolumeChanged(_ sender: NSSlider) {
        let value:Int = Int(sender.intValue)
        LogUtils.log(message: "onAudioMixingVolumeChanged \(value)", level: .info)
        agoraKit.adjustAudioMixingVolume(value)
    }
    
    @IBAction func onAudioMixingPlaybackVolumeChanged(_ sender: NSSlider) {
        let value:Int = Int(sender.intValue)
        LogUtils.log(message: "onAudioMixingPlaybackVolumeChanged \(value)", level: .info)
        agoraKit.adjustAudioMixingPlayoutVolume(value)
    }
    
    @IBAction func onAudioMixingPublishVolumeChanged(_ sender: NSSlider) {
        let value:Int = Int(sender.intValue)
        LogUtils.log(message: "onAudioMixingPublishVolumeChanged \(value)", level: .info)
        agoraKit.adjustAudioMixingPublishVolume(value)
    }
    
    @IBAction func onPlayEffect(_ sender:NSButton){
        if let filepath = Bundle.main.path(forResource: "audioeffect", ofType: "mp3") {
            let result = agoraKit.playEffect(EFFECT_ID, filePath: filepath, loopCount: -1, pitch: 1, pan: 0, gain: 100, publish: true)
            if result != 0 {
                self.showAlert(title: "Error", message: "playEffect call failed: \(result), please check your params")
            }
        }
    }
    
    @IBAction func onPlayEffect2(_ sender:NSButton){
        if let filepath = Bundle.main.path(forResource: "effectA", ofType: "wav") {
            let result = agoraKit.playEffect(EFFECT_ID_2, filePath: filepath, loopCount: -1, pitch: 1, pan: 0, gain: 100, publish: true)
            if result != 0 {
                self.showAlert(title: "Error", message: "playEffect call failed: \(result), please check your params")
            }
        }
    }
    
    @IBAction func onStopEffect(_ sender:NSButton){
        let result = agoraKit.stopEffect(EFFECT_ID)
        if result != 0 {
            self.showAlert(title: "Error", message: "stopEffect call failed: \(result), please check your params")
        }
    }
    
    @IBAction func onStopEffect2(_ sender:NSButton){
        let result = agoraKit.stopEffect(EFFECT_ID_2)
        if result != 0 {
            self.showAlert(title: "Error", message: "stopEffect call failed: \(result), please check your params")
        }
    }
    
    @IBAction func onPauseEffect(_ sender:NSButton){
        let result = agoraKit.pauseEffect(EFFECT_ID)
        if result != 0 {
            self.showAlert(title: "Error", message: "pauseEffect call failed: \(result), please check your params")
        }
    }
    
    @IBAction func onResumeEffect(_ sender:NSButton){
        let result = agoraKit.resumeEffect(EFFECT_ID)
        if result != 0 {
            self.showAlert(title: "Error", message: "resumeEffect call failed: \(result), please check your params")
        }
    }
    
    @IBAction func onAudioEffectVolumeChanged(_ sender: NSSlider) {
        let value:Int = Int(sender.intValue)
        LogUtils.log(message: "onAudioEffectVolumeChanged \(value)", level: .info)
        agoraKit.setEffectsVolume(value)
    }
    
    @IBAction func onAudioEffectVolumeChanged2(_ sender: NSSlider) {
        //TODO
        let value:Int = Int(sender.intValue)
        LogUtils.log(message: "onAudioEffectVolumeChanged \(value)", level: .info)
        agoraKit.setVolumeOfEffect(EFFECT_ID_2, withVolume: Int32(value))
    }
    
    func layoutVideos(_ count: Int) {
        videos = []
        for i in 0...count - 1 {
            let view = VideoView.createFromNib()!
            if(i == 0) {
                view.placeholder.stringValue = "Local"
                view.type = .local
                view.statsInfo = StatisticsInfo(type: .local(StatisticsInfo.LocalInfo()))
            } else {
                view.placeholder.stringValue = "Remote \(i)"
                view.type = .remote
                view.statsInfo = StatisticsInfo(type: .remote(StatisticsInfo.RemoteInfo()))
            }
            view.audioOnly = true
            videos.append(view)
        }
        // layout render view
        container.layoutStream(views: videos)
    }
}

/// agora rtc engine delegate events
extension AudioMixing: AgoraRtcEngineDelegate {
    /// callback when warning occured for agora sdk, warning can usually be ignored, still it's nice to check out
    /// what is happening
    /// Warning code description can be found at:
    /// en: https://docs.agora.io/en/Voice/API%20Reference/oc/Constants/AgoraWarningCode.html
    /// cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraWarningCode.html
    /// @param warningCode warning code of the problem
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        LogUtils.log(message: "warning: \(warningCode.rawValue)", level: .warning)
    }
    
    /// callback when error occured for agora sdk, you are recommended to display the error descriptions on demand
    /// to let user know something wrong is happening
    /// Error code description can be found at:
    /// en: https://docs.agora.io/en/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
    /// cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
    /// @param errorCode error code of the problem
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        LogUtils.log(message: "error: \(errorCode)", level: .error)
        self.showAlert(title: "Error", message: "Error \(errorCode.rawValue) occur")
    }
    
    /// callback when a remote user is joinning the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param elapsed time elapse since current sdk instance join the channel in ms
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        LogUtils.log(message: "remote user join: \(uid) \(elapsed)ms", level: .info)
        
        // find a VideoView w/o uid assigned
        if let remoteVideo = videos.first(where: { $0.uid == nil }) {
            remoteVideo.uid = uid
        } else {
            LogUtils.log(message: "no video canvas available for \(uid), cancel bind", level: .warning)
        }
    }
    
    /// callback when a remote user is leaving the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param reason reason why this user left, note this event may be triggered when the remote user
    /// become an audience in live broadcasting profile
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        LogUtils.log(message: "remote user left: \(uid) reason \(reason)", level: .info)
        
        // to unlink your view from sdk, so that your view reference will be released
        // note the video will stay at its last frame, to completely remove it
        // you will need to remove the EAGL sublayer from your binded view
        if let remoteVideo = videos.first(where: { $0.uid == uid }) {
            remoteVideo.uid = nil
        } else {
            LogUtils.log(message: "no matching video canvas for \(uid), cancel unbind", level: .warning)
        }
    }
    
    
    /// Reports the statistics of the current call. The SDK triggers this callback once every two seconds after the user joins the channel.
    /// @param stats stats struct
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportRtcStats stats: AgoraChannelStats) {
        videos[0].statsInfo?.updateChannelStats(stats)
    }
    
    /// Reports the statistics of the uploading local audio streams once every two seconds.
    /// @param stats stats struct
    func rtcEngine(_ engine: AgoraRtcEngineKit, localAudioStats stats: AgoraRtcLocalAudioStats) {
        videos[0].statsInfo?.updateLocalAudioStats(stats)
    }
    
    /// Reports the statistics of the audio stream from each remote user/host.
    /// @param stats stats struct for current call statistics
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStats stats: AgoraRtcRemoteAudioStats) {
        videos.first(where: { $0.uid == stats.uid })?.statsInfo?.updateAudioStats(stats)
    }
    
    /// Reports which users are speaking, the speakers' volumes, and whether the local user is speaking.
    /// @params speakers volume info for all speakers
    /// @params totalVolume Total volume after audio mixing. The value range is [0,255].
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        for volumeInfo in speakers {
            if (volumeInfo.uid == 0) {
                videos[0].statsInfo?.updateVolume(volumeInfo.volume)
            } else {
                videos.first(where: { $0.uid == volumeInfo.uid })?.statsInfo?.updateVolume(volumeInfo.volume)
            }
        }
    }
}
