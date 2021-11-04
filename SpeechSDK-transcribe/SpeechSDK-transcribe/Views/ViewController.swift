//
//  ViewController.swift
//  SpeechSDK-transcribe
//
//  Created by kazunori.aoki on 2021/10/29.
//

import UIKit
import Speech

class ViewController: UIViewController {

    // MARK: UI
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var recordButton: UIButton!


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

        // 承認されるまで、無効にする
        recordButton.isEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        speechRecognizer.delegate = self

        requestAuthorization()
    }


    // MARK: IBAction
    @IBAction func tapRecordButton(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                try startRecording()
                recordButton.setTitle("Stop Recording", for: [])
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
}


// MARK: - Private
private extension ViewController {

    func requestAuthorization() {

        SFSpeechRecognizer.requestAuthorization { authStatus in

            // MainThreadで行う
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true

                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton
                        .setTitle("User denied access to speech recognition", for: .disabled)

                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton
                        .setTitle("Speech recognition restricted on this device", for: .disabled)

                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton
                        .setTitle("Speech recognition not yet authorized", for: .disabled)

                default:
                    self.recordButton.isEnabled = false
                }
            }
        }
    }

    func startRecording() throws {

        // 実行中の場合は、前のタスクをキャンセルする
        recognitionTask?.cancel()
        recognitionTask = nil

        // audio session configuration
        let audioSession = AVAudioSession.sharedInstance()
        /*
         ** オーディオ接心の設定 **
         - category:  オーディオ動作、.recorde: オーディオ録音用
         - mode: カテゴリの特別な動作、 .measurement:アプリがオーディオ入力または出力の測定を実行していることを示すモード。
         - option: オーディオの動作を指定する、.duckOthers: このセッションのオーディオの再生中に他のオーディオセッションの音量を下げるオプション。
         */
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        /*
         ** オプションを指定し、アクティブ/非アクティブを設定
         - active: アクティブの有無（電話など優先度の高い項目が来た場合、失敗する）
            Errorがthrowされる（AVAudioSession.ErrorCode.isBusy）
         - .notifyOthersOnDeactivation: 無効になったことをシステムが他のアプリに通知する必要があることを示す
         */
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        // シングルトン入力オーディオノード
        let inputNode = audioEngine.inputNode

        // 音声認識リクエストの構成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
        }
        // 発話ごとに中間結果を返すか
        recognitionRequest.shouldReportPartialResults = true

        // TODO: 認識させるための文字列
        recognitionRequest.contextualStrings = ["極主夫道", "ごくしゅふどう", "ヴァイオレット・エヴァーガーデン"]

        // 音声認識データをデバイスに保持するか
        recognitionRequest.requiresOnDeviceRecognition = false

        speechRecognizer.recognitionTask(with: recognitionRequest, delegate: self)

        // 認識タスクの作成、タスクへの参照を保持し、キャンセルできるようにする
        // recognitionTask: 認識プロセスの開始
//        recognitionTask = speechRecognizer
//            .recognitionTask(with: recognitionRequest) { result, error in
//            var isFinal = false
//
//            if let result = result {
//                // textViewへの反映
//                self.textView.text = result.bestTranscription.formattedString
//                isFinal = result.isFinal
////                print("Text: \(result.bestTranscription.formattedString)")
////                print("segment: \(result.bestTranscription.segments)")
////                print("segment: \(result.bestTranscription.segments[0].substring)")
////                print("isFinal: \(result.isFinal)")
//
//                // 発話が終わってからの時間
//                if let duration = result.bestTranscription.segments.first?.duration {
////                    print("duration: \(result.bestTranscription.segments.first!.duration)")
//                    print(duration == 0.0 ? "喋ってる" : "喋ってない")
//                }
//            }
//
//            // タイムアウト（1min）もここに入る
//            // エラーのなかにタイムアウトが格納される
//            if error != nil || isFinal {
//                // 問題があったら停止
//                self.audioEngine.stop()
//                // 指定したバスのオーディオタップを削除する
//                inputNode.removeTap(onBus: 0)
//
//                self.recognitionRequest = nil
//                self.recognitionTask = nil
//
//                print("end")
////                print("isFinal: \(result?.isFinal)") // タイムアウトの場合nil
//
//                self.recordButton.isEnabled = true
//                self.recordButton.setTitle("Start Recording!", for: [])
//
//                self.textView.text = ""
//            }
//        }

        // マイク設定
        // 指定したバスの出力形式の取得
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // 指定したバスにオーディオタップをインストールし、
        // ノードの出力を録音、監視する
        inputNode.installTap(onBus: 0,
                             bufferSize: 2048,
                             format: recordingFormat) { (buffer: AVAudioPCMBuffer,
                                                         when: AVAudioTime) in
            // メインスレッド以外で呼ばれる場合もある
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // 話し始める合図
        textView.text = "(Go ahead, I'm listening)"
    }
}


// MARK: - SFSpeechRecognizerDelegate
extension ViewController: SFSpeechRecognizerDelegate {

    // 可用性の変更（使えるようになった、使えなくなった）の検知
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer,
                          availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording!", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }

}

extension ViewController: SFSpeechRecognitionTaskDelegate {

    // 音声入力があったとき
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        print("🔰🔰🔰speechRecognitionTask transcription")
//        print("task: \(task)")
//        print("transcription: \(transcription)")

        if let duration = transcription.segments.first?.duration {
//                    print("duration: \(result.bestTranscription.segments.first!.duration)")
            print(duration == 0.0 ? "喋ってる" : "喋ってない")
        }
    }

    // 終了検知
    func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        print("speechRecognitionTask FinishedReadingAudio")
//        print("task: \(task)")
        /*
         starting = 0
         running = 1
         finishing = 2
         canceling = 3
         completed = 4
         */
        // この段階では、終了ボタン押下後、runningになっている
//        print("state: \(task.state.rawValue)")
//        print("isFinishing: \(task.isFinishing)")
//        print("isCancelled: \(task.isCancelled)")
//        print("error: \(task.error)")
    }

    // 終了後の
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        print("speechRecognitionTask successfully")
//        print("successfully: \(successfully)")
//        print("task: \(task)")
        // この段階では、終了ボタン押下後、completedになっている
        print("state: \(task.state.rawValue)")
        print("isFinishing: \(task.isFinishing)")
        print("isCancelled: \(task.isCancelled)")
        print("error: \(task.error?.code) \n \(task.error?.domain) \n \(task.error?.localizedDescription)")
        // TODO: 再スタート
    }

    // すべての音声出力完了後の出力
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        print("speechRecognitionTask recognitionResult")
//        print("recognitionResult: \(recognitionResult)")
//        print("task: \(task)")
    }

    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        print("speechRecognitionTaskWasCancelled")
//        print("task: \(task)")
    }

    // ソースオーディオ時の開始検知
    func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        print("speechRecognitionDidDetectSpeech")
//        print("task: \(task)")
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
