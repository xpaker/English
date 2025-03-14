//
//  ContentView.swift
//  English
//
//  Created by 伍兵 on 2025/3/1.
//

import SwiftUI
import AVFoundation

var player: AVAudioPlayer?

struct ContentView: View {
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var playbackRate: Float = 1.0
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var volume: Float = 0.5
    @State private var subtitles: [Subtitle] = []
    @State private var audioFiles: [URL] = []
    @State private var selectedFile: String?
    @State private var mp3Path: String = "/Users/wubing/Downloads/english/mp3"
    @State private var mp3FileNames: [String] = []
    
    @State private var playTimeInt: Int = 3
    @State private var currentPlayTimeInt: Int = 0

    @State private var repeatSubtitle:Subtitle?
    @State private var repeatSubtitleIndex:Int = 0
    
    // 是否重复播放句子
    @State private var isRepeatSubtitle: Bool = false
    // 单句重复次数
    @State private var repeatSubtitleInt: Int = 3
    // 当前单句重复次数
    @State private var currentRepeatSubtitleInt: Int = 0
    // 是否是最后一句
    @State private var isLastSubtitle:Bool = false

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    



    
    @State private var isShowingDirectoryPicker = false
    
    var body: some View {
        VStack {
            // 文件选择器
            Picker("选择音频文件", selection: $selectedFile) {
                ForEach(mp3FileNames ?? [], id: \.self) { file in
                    Text(file).tag(file)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedFile) { newFile in
                if let file = newFile {
                    loadAudio(file)
                }
            }
            
            // 播放控制
            HStack {
                Button(action: skipBackward) {
                    Image(systemName: "gobackward.10")
                }
                
                Button(action: togglePlay) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }
                
                Button(action: skipForward) {
                    Image(systemName: "goforward.10")
                }
            }
            
            HStack {
                // 修改这里，将秒数转换为时间格式
                Text(formatTime(currentTime))
                // 播放进度
                Slider(value: $currentTime, in: 0...duration, onEditingChanged: sliderEditingChanged)
                // 修改这里，将秒数转换为时间格式
                Text(formatTime(duration))
            }
            HStack {
                // 播放速度
                Picker("Speed", selection: $playbackRate) {
                    Text("0.5x").tag(0.5)
                    Text("1.0x").tag(1.0)
                    Text("1.5x").tag(1.5)
                    Text("2.0x").tag(2.0)
                }
                .onChange(of: playbackRate) { newValue in
                    guard let player = player else { return }
                    // 确保在修改rate之前暂停播放
                    let wasPlaying = isPlaying
                    if wasPlaying {
                        player.pause()
                    }
                    player.rate = newValue
                    if wasPlaying {
                        player.play()
                    }
                    print("newValue=\(newValue)")
                }
                .frame(width:300)
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
                
                // 添加单句重复次数选择器
                Picker("单句重复", selection: $repeatSubtitleInt) {
                    Text("1次").tag(1)
                    Text("2次").tag(2)
                    Text("3次").tag(3)
                    Text("4次").tag(4)
                    Text("5次").tag(5)
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 150)
                
                Spacer()
                
                // 添加播放次数选择器
                Picker("播放次数", selection: $playTimeInt) {
                    Text("1次").tag(1)
                    Text("2次").tag(2)
                    Text("3次").tag(3)
                    Text("4次").tag(4)
                    Text("5次").tag(5)
                }
                .onChange(of: playTimeInt) { newValue in
                    print("播放次数已更改为: \(newValue)次")
                    currentPlayTimeInt = 0  // 重置当前播放次数
                    playTimeInt = newValue
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 150)
                
                Spacer()
                
                // 音量控制
                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: $volume, in: 0...1)
                        .onChange(of: volume) { newValue in
                            player?.volume = newValue
                    }
                    Image(systemName: "speaker.wave.3.fill")
                }.frame(width:300)

            }
            // 字幕显示
            ScrollViewReader { proxy in
                ScrollView {
                    ForEach(subtitles) { subtitle in
                        Text(subtitle.text)
                            .font(.system(size: 16))
                            .foregroundColor(currentTime >= subtitle.startTime && currentTime <= subtitle.endTime ? .blue : .primary)
                            .padding()
                            .onTapGesture {

                                playSubtitle2(subtitle.startTime)
 
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .id(subtitle.id)  // 添加id用于定位
                    }
                }
                .onChange(of: currentTime) { _ in
                    if let currentSubtitle = subtitles.first(where: { $0.startTime <= currentTime && $0.endTime > currentTime }) {
                        withAnimation {
                            proxy.scrollTo(currentSubtitle.id, anchor: .center)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .focusable()  // 添加这行，使视图能够接收键盘事件
        .onAppear(perform: setupFileList)
        .onReceive(timer) { _ in
            updateTime()
        }
        .onKeyPress { keyPress in
            print("按下的键：", keyPress.key)
            switch keyPress.key {
            case .upArrow:
                playPreviousAudioFile()
                return .handled
            case .downArrow:
                playNextAudioFile()
                return .handled
            case .leftArrow:
                playPreviousSubtitle()
                return .handled
            case .rightArrow:
                playNextSubtitle()
                return .handled
            case .space:
                togglePlay()
                return .handled
            case .return:
                repeatCurrentSubtitle()
                return .handled
            default:
                return .ignored
            }
        }
        .onAppear {
            // 首次启动时显示目录选择器
            if mp3Path.isEmpty {
                isShowingDirectoryPicker = true
                return
            }
            mp3FileNames = getAllMp3FilesPath(mp3Path)
            // 加载第一个音频文件
            if let firstFile = mp3FileNames.first {
                selectedFile = firstFile
            } else {
                selectedFile = nil
            }
        }

    }

    
    //得到一个目录路径下，所有的mp3文件的路径，返回一个数组。
    func getAllMp3FilesPath(_ mp3DirPath: String) -> [String] {
        print("getAllMp3FilesPath mp3DirPath=\(mp3DirPath)")
        let fileManager = FileManager.default
        var mp3Files: [String] = []
        
        do {
            // 使用 enumerator(atPath:) 方法递归遍历目录
            if let enumerator = fileManager.enumerator(atPath: mp3DirPath) {
                for case let file as String in enumerator {
                    if file.lowercased().hasSuffix(".mp3") {
                        // 拼接相对路径
                        var relativePath = (mp3DirPath as NSString).appendingPathComponent(file)
                        // 去除相对路径中开始位置的的path符串
                        relativePath=relativePath.replacingOccurrences(of: mp3DirPath, with: "")
                        mp3Files.append(relativePath)
                    }
                }
                mp3Files.sort()
            }
        } catch let error as NSError {
            if error.code == 257 {
                print("权限被拒绝: \(error.localizedDescription)")
                // 你可以在这里显示一个警告框给用户
            } else {
                print("读取目录时出错: \(error.localizedDescription)")
            }
        }
        if mp3Files == nil{
            mp3Files = []
        }
        return mp3Files
    }

    //播放下一个音频文件
    func playNextAudioFile() {
        if let currentIndex = mp3FileNames.firstIndex(of: selectedFile ?? "") {
            let nextIndex = (currentIndex + 1) % mp3FileNames.count
            selectedFile = mp3FileNames[nextIndex]
            loadAudio(selectedFile ?? "")
        }
    }

    // 播放上一个音频文件
    func playPreviousAudioFile() {
        if let currentIndex = mp3FileNames.firstIndex(of: selectedFile ?? "") {
            let previousIndex = (currentIndex - 1 + mp3FileNames.count) % mp3FileNames.count
            selectedFile = mp3FileNames[previousIndex]
            loadAudio(selectedFile ?? "")
        }
    }
    
    // 播放下一句子
    func playNextSubtitle() {
        if let currentIndex = subtitles.firstIndex(where: { $0.startTime <= currentTime && $0.endTime > currentTime }) {
            let nextIndex = (currentIndex + 1) % subtitles.count
            // 直接跳转到下一句的开始时间
            currentTime = subtitles[nextIndex].startTime + 0.01 // 加一个小偏移量确保只高亮当前句
            player?.pause()
            // 暂停0.2秒
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                player?.play()
            }
            player?.play()
            seek(to: currentTime)
            repeatSubtitle = subtitles[nextIndex]
            repeatSubtitleIndex = nextIndex
        }
    }
   
    // 播放上一句子
    func playPreviousSubtitle() {
        if let currentIndex = subtitles.firstIndex(where: { $0.startTime <= currentTime && $0.endTime > currentTime }) {
            let previousIndex = (currentIndex - 1 + subtitles.count) % subtitles.count
            // 直接跳转到上一句的开始时间
            currentTime = subtitles[previousIndex].startTime + 0.01 // 加一个小偏移量确保只高亮当前句
            player?.pause()
            // 暂停0.2秒
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                player?.play()
            }
            player?.play()
            seek(to: currentTime)
            repeatSubtitle = subtitles[previousIndex]
            repeatSubtitleIndex = previousIndex
        }
    }

    // 播放最后句子
    func playLastSubtitle() {
         // 直接跳转到上一句的开始时间
        currentTime = subtitles[subtitles.count-1].startTime + 0.01 // 加一个小偏移量确保只高亮当前句
        player?.pause()
        // 暂停0.2秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
             player?.play()
        }
        player?.play()
        seek(to: currentTime)
        repeatSubtitle = subtitles[subtitles.count-1]
        repeatSubtitleIndex = subtitles.count-1
    }
    
    // 播放当前句子
    func playSubtitle() {
        if let currentIndex = subtitles.firstIndex(where: { $0.startTime <= currentTime && $0.endTime > currentTime }) {
            repeatSubtitle = subtitles[currentIndex]
            repeatSubtitleIndex = currentIndex
            currentRepeatSubtitleInt = 0
        }
    }
    // 播放当前句子
    func playSubtitle2(_ t:Double) {
        if let currentIndex = subtitles.firstIndex(where: { $0.startTime <= t && $0.endTime > t }) {
            repeatSubtitle = subtitles[currentIndex]
            repeatSubtitleIndex = currentIndex
            currentRepeatSubtitleInt = 0
        }
        seek(to: t )
    }
    
    // 重复当前这一句
    func repeatCurrentSubtitle() {
        guard let index = subtitles.firstIndex(where: { $0.startTime <= currentTime && $0.endTime > currentTime }) else { return }
        
        // 暂停播放
        player?.pause()
        
        // 跳转到当前句子的开始时间
        seek(to: subtitles[index].startTime)
        
        // 延迟0.1秒后重新播放，确保跳转完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.player?.play()
        }
        
        repeatSubtitle = subtitles[index]
        repeatSubtitleIndex = index
        currentRepeatSubtitleInt = 0
        
    }
    
    private func togglePlay() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func skipBackward() {
        guard let player = player else { return }
        let currentTime = player.currentTime().seconds
        let newTime = max(currentTime - 10, 0)
        seek(to: newTime)
    }
    
    private func skipForward() {
        guard let player = player else { return }
        let currentTime = player.currentTime().seconds
        let newTime = min(currentTime + 10, duration)
        seek(to: newTime)
    }
    
    private func seek(to time: Double) {
        guard let player = player else { return }
        let targetTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: targetTime)
    }
    
    @State private var isSeeking = false  // 新增状态，用于标记是否正在拖动进度条
    
    private func sliderEditingChanged(editingStarted: Bool) {
        isSeeking = editingStarted  // 更新拖动状态
        if !editingStarted {
            // 得到currentTime的句子
            let currentIndex = subtitles.firstIndex(where: { $0.startTime <= currentTime && $0.endTime > currentTime })
            if currentIndex != nil {
                repeatSubtitle = subtitles[currentIndex!]
                currentTime = repeatSubtitle?.startTime ?? 0
                currentRepeatSubtitleInt = 0
                isRepeatSubtitle = true
                seek(to: currentTime)
            }else{
                isRepeatSubtitle = false
                seek(to: currentTime)
            }
        }
    }
    
    private func updateTime() {
        guard let player = player, !isSeeking else { return }
        currentTime = player.currentTime().seconds
        
        // 单句是否重复播放
        if isRepeatSubtitle == false {
            return
        }

        // 单句是否重复播放
        if repeatSubtitleInt <= 1{
            //单句不能重复播放
            return
        }

        //当isRepeatSubtitle = true时执行下面的代码，让单句重复
        if repeatSubtitle == nil && subtitles.isEmpty == false && subtitles.count > 0 {
            repeatSubtitle = subtitles[0]
        }
        
        //当isLastSubtitle == true时，让音频播完，不检查单句重复
        if isLastSubtitle == true {
            return
        }


        //检查最后一句
        
        //print("currentTime=\(currentTime) repeatSubtitle?.endTime ?? duration-5  = \(repeatSubtitle?.endTime ?? duration-5 )")
        
        if isLastSubtitle == false && repeatSubtitleIndex >= subtitles.count-1 && currentTime > subtitles[subtitles.count-1].endTime ?? duration-5  {
            //print("isLast")
            if currentRepeatSubtitleInt >= repeatSubtitleInt-1{
                currentRepeatSubtitleInt = 0
                isLastSubtitle = true
                playSubtitle()
                //print("11=\(repeatSubtitle?.endTime)")
                return
            }else{
                // 播放最后的句子
                playLastSubtitle()
                currentRepeatSubtitleInt = currentRepeatSubtitleInt+1
                //print("22=\(repeatSubtitle?.endTime)")
                return
            }
            
        }
        //检查不是最后的句子 isLastSubtitle == false
        if repeatSubtitleIndex < subtitles.count-1 &&  isLastSubtitle == false && repeatSubtitle != nil &&  currentTime >= repeatSubtitle?.endTime ?? duration-5 {
            if currentRepeatSubtitleInt >= repeatSubtitleInt-1{
                currentRepeatSubtitleInt = 0
                playSubtitle()
                //print("1=\(repeatSubtitle?.endTime)")
            }else{
                // 播放上一句
                playPreviousSubtitle()
                currentRepeatSubtitleInt = currentRepeatSubtitleInt+1
                //print("2=\(repeatSubtitle?.endTime)")
            }
        }

     }

    private func setupFileList() {
        let fileManager = FileManager.default
        //if let resourcePath = Bundle.main.resourcePath {
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let files = try fileManager.contentsOfDirectory(atPath: resourcePath)
                audioFiles = files
                    .filter { $0.hasSuffix(".mp3") }
                    .map { URL(fileURLWithPath: resourcePath).appendingPathComponent($0) }
            } catch {
                print("Error reading directory: \(error)")
            }
        }
    }
    
    private func loadAudio(_ file: String) {
        print(file);
        repeatSubtitle = nil
        currentRepeatSubtitleInt = 0
        isLastSubtitle = false
        isRepeatSubtitle = true
        
        let audioURL = URL(fileURLWithPath: mp3Path).appendingPathComponent(file)
        if player != nil {
            player?.pause()
            player = nil
        }
        if player == nil {
            do {
                player = AVPlayer(url: audioURL)
                // 确保在播放前设置rate
                player?.rate = playbackRate
                // 添加这一行，允许在播放时修改播放速度
                player?.automaticallyWaitsToMinimizeStalling = false
                player?.play()
                print("player?.rate=\(player?.rate)")
            } catch {
                print("打开音乐失败\(error.localizedDescription)")
            }
        }

        
        duration = player?.currentItem?.asset.duration.seconds ?? 0
        isPlaying = true
        volume = 0.5
        currentTime = 0
        
        // 添加播放结束监听
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, 
                                               object: player?.currentItem, 
                                               queue: .main) { [self] _ in
            self.handlePlaybackEnded()
        }
        
        // 加载对应的字幕文件
        let lrcURL = audioURL.deletingPathExtension().appendingPathExtension("lrc")
        let relativePath = lrcURL.path.replacingOccurrences(of: mp3Path, with: "")
        loadSubtitles(from: relativePath)
    }
    

    
    // 修改 handlePlaybackEnded 方法
    private func handlePlaybackEnded() {

        // 在这里可以添加播放结束后的其他逻辑，比如自动播放下一首等
        currentPlayTimeInt += 1
        if currentPlayTimeInt >= playTimeInt {
            currentPlayTimeInt = 0
            // 自动播放下一首
            if let index = mp3FileNames.firstIndex(of: selectedFile!),
               index < mp3FileNames.count - 1 {
                selectedFile = mp3FileNames[index + 1]
                loadAudio(selectedFile!)
            } else {
                // 如果已经是最后一首，你可以选择重新播放或者停止播放
                selectedFile = mp3FileNames.first
                loadAudio(selectedFile!)
            }
        } else {
            currentTime = 0
            loadAudio(selectedFile ?? "")
        }
    }


    private func loadSubtitles(from fileName: String) {
        var url = URL(fileURLWithPath: mp3Path+fileName)
        subtitles.removeAll()
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            var previousSubtitle: Subtitle? = nil
            
            for line in lines {
                if let range = line.range(of: "]"),
                   let time = parseTime(String(line[line.startIndex..<range.upperBound])) {
                    let text = String(line[range.upperBound...])
                    
                    // 更新上一行字幕的结束时间为当前行的开始时间
                    if let prev = previousSubtitle {
                        subtitles[subtitles.count - 1] = Subtitle(
                            startTime: prev.startTime,
                            endTime: time,
                            text: prev.text
                        )
                    }
                    
                    // 添加新字幕，暂时使用默认结束时间
                    let newSubtitle = Subtitle(
                        startTime: time,
                        endTime: time + 5, // 默认值，会被下一行覆盖
                        text: text
                    )
                    subtitles.append(newSubtitle)
                    previousSubtitle = newSubtitle
                }
            }
            // 处理最后一行的结束时间
            if let prev = previousSubtitle {
                subtitles[subtitles.count - 1] = Subtitle(
                    startTime: prev.startTime,
                    //最后一句结束时间是总时长减5秒
                    endTime: duration-5,
                    text: prev.text
                )
            }
            
            isRepeatSubtitle = true
            // 检查时间点是否是递增的
            if subtitles.isEmpty || subtitles.count < 1  {
                isRepeatSubtitle = false
                return
            }
            for i in 1..<subtitles.count {
                if subtitles[i].startTime <= subtitles[i - 1].startTime {
                    isRepeatSubtitle = false
                    return
                }
            }
            //print("subtitles=\(subtitles)")
        } catch {
            print("Error loading subtitles: \(error)")
        }
    }
    
    private func parseTime(_ timeString: String) -> Double? {
        // 解析时间字符串，例如"[00:01.00]"
        let components = timeString
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .components(separatedBy: ":")
        if components.count == 2,
           let minutes = Double(components[0]),
           let seconds = Double(components[1]) {
            return minutes * 60 + seconds
        }
        return nil
    }
    
    private func setupPlayer() {
        // 这里可以初始化播放器，加载默认音频
        // 示例代码：
        if let url = Bundle.main.url(forResource: "sample", withExtension: "mp3") {
            player = AVPlayer(url: url)
            duration = player?.currentItem?.asset.duration.seconds ?? 0
        }
    }

        // 添加辅助函数，将秒数转换为 mm:ss 格式
    private func formatTime(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        // 确保传入的时间值是非负数
        let safeSeconds = max(0, seconds)
        return formatter.string(from: TimeInterval(safeSeconds)) ?? "0:00"
    }
}

struct Subtitle: Identifiable {
    let id = UUID()
    let startTime: Double
    var endTime: Double
    let text: String
}

#Preview {
    ContentView()
}

