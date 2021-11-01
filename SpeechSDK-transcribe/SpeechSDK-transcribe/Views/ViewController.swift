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


// MARK: - Setup
private extension ViewController {

    func setupRecord() throws {

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
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)

                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)

                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)

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

        // 音声認識データをデバイスに保持するか
        recognitionRequest.requiresOnDeviceRecognition = false

        // 認識タスクの作成、タスクへの参照を保持し、キャンセルできるようにする
        // recognitionTask: 認識プロセスの開始
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false

            if let result = result {
                // textViewへの反映
                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                print("Text: \(result.bestTranscription.formattedString)")
            }

            if error != nil || isFinal {
                // 問題があったら停止
                self.audioEngine.stop()
                // 指定したバスのオーディオタップを削除する
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording!", for: [])
            }
        }

        // マイク設定
        // 指定したバスの出力形式の取得
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // 指定したバスにオーディオタップをインストールし、
        // ノードの出力を録音、監視する
        inputNode.installTap(onBus: 0,
                             bufferSize: 1024,
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

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer,
                          availabilityDidChange available: Bool)
    {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording!", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }
}
