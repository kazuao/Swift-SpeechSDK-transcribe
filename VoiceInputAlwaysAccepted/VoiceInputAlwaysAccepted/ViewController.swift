//
//  ViewController.swift
//  VoiceInputAlwaysAccepted
//
//  Created by kazunori.aoki on 2021/11/04.
//

import UIKit
import Speech

class ViewController: UIViewController {

    // MARK: UI
    @IBOutlet weak var textView: UITextView!


    // MARK: Property
    // 認識する言語を設定
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Const.localeJP))!
    // 音声認識するための要求
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    // 音声認識の進行状況を監視するためのタスクオブジェクト
    private var recognitionTask: SFSpeechRecognitionTask?
    // リアルタイムレンダリング制約を構成するオブジェクト
    private let audioEngine = AVAudioEngine()


    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        speechRecognizer.delegate = self
        requestAuthorization()
    }
}


// MARK: - Private
private extension ViewController {

    /// 権限の取得
    func requestAuthorization() {

        SFSpeechRecognizer.requestAuthorization { authStatus in

            // MainThreadで行う
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.restartRecording()

                case .denied:
                    print("error")

                case .restricted:
                    print("error")

                case .notDetermined:
                    print("error")

                @unknown default:
                    fatalError()
                }
            }
        }
    }

    func restartRecording() {

        recognitionTask?.cancel()
        recognitionTask?.finish()

//        audioEngine.stop()
//        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask = nil
        recognitionRequest = nil

        do {
            print("Restart")
            try self.startRecording()
        } catch {
            // TODO: Alert
        }
    }

    func startRecording() throws {

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)

        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
        }

        recognitionRequest.shouldReportPartialResults = true

        // TODO: 認識させるための文字列
        recognitionRequest.contextualStrings = ["極主夫道", "ごくしゅふどう", "ヴァイオレット・エヴァーガーデン"]

        recognitionRequest.requiresOnDeviceRecognition = false

        speechRecognizer.recognitionTask(with: recognitionRequest, delegate: self)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0,
                             bufferSize: 2048,
                             format: recordingFormat) { (buffer: AVAudioPCMBuffer,
                                                         when: AVAudioTime) in

            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        textView.text = "go"
    }
}


// MARK: - SFSpeechRecognizerDelegate
extension ViewController: SFSpeechRecognizerDelegate {

    // 可用性の変更（使えるようになった、使えなくなった）の検知
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer,
                          availabilityDidChange available: Bool) {
        // Socket通信失敗等の処理
        if available {
        } else {
        }
    }
}


// MARK: - SFSpeechRecognitionTaskDelegate
extension ViewController: SFSpeechRecognitionTaskDelegate {

    // 音声入力があったとき
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        print("speechRecognitionTask transcription")
        textView.text = transcription.formattedString

        if let duration = transcription.segments.first?.duration {
            print(duration == 0.0 ? "喋ってる" : "喋ってない")
        }
    }

    // 終了後の
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        print("speechRecognitionTask successfully")
        restartRecording()
    }
}

extension Error {
    var code: Int {
        return (self as NSError).code
    }

    var domain: String {
        return (self as NSError).domain
    }
}
