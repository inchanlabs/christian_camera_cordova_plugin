import OSCameraLib
import AVFoundation

@objc(OSCamera)
class OSCamera: CDVPlugin {

    var plugin: OSCAMRActionDelegate?
    var callbackId: String = ""

    override func pluginInitialize() {
        self.plugin = OSCAMRFactory.createCameraWrapper(
            withDelegate: self,
            and: self.viewController
        )
    }

    override func onAppTerminate() {
        self.commandDelegate.run { [weak self] in
            guard let self = self else { return }

            self.plugin?.cleanTemporaryFiles()
        }
    }

    // MARK: - Take Picture

    @objc(takePicture:)
    func takePicture(command: CDVInvokedUrlCommand) {

        self.callbackId = command.callbackId

        guard let parametersDictionary = command.argument(at: 0) as? [String: Any],
              let parametersData = try? JSONSerialization.data(
                withJSONObject: parametersDictionary
              ),
              let parameters = try? JSONDecoder().decode(
                OSCAMRTakePictureParameters.self,
                from: parametersData
              )
        else {
            self.callback(error: .takePictureArguments)
            return
        }

        // sourceType == 0 means gallery
        // Keep this behavior unchanged.
        if parameters.sourceType == 0 {
            return self.chooseSinglePicture(
                allowEdit: parameters.allowEdit
            )
        }

        guard let options = try? OSCAMRPictureOptions(
            from: parameters
        )
        else {
            self.callback(error: .takePictureArguments)
            return
        }

        /*
         Camera permission must be explicitly handled on iOS
         before calling OSCameraLib.
        */
        self.requestCameraPermission { [weak self] granted in

            guard let self = self else {
                return
            }

            guard granted else {
                self.sendCameraPermissionError()
                return
            }

            /*
             Camera APIs must be executed on the main thread.
            */
            DispatchQueue.main.async { [weak self] in

                guard let self = self else {
                    return
                }

                self.plugin?.captureMedia(
                    with: options
                )
            }
        }
    }

    // MARK: - Camera Permission

    private func requestCameraPermission(
        completion: @escaping (Bool) -> Void
    ) {

        let authorizationStatus =
            AVCaptureDevice.authorizationStatus(
                for: .video
            )

        switch authorizationStatus {

        case .authorized:

            // Permission already granted.
            completion(true)

        case .notDetermined:

            /*
             This is the important part.

             iOS will display:

             "This app needs access to the camera..."

             using NSCameraUsageDescription from Info.plist.
            */
            AVCaptureDevice.requestAccess(
                for: .video
            ) { granted in

                DispatchQueue.main.async {
                    completion(granted)
                }
            }

        case .denied,
             .restricted:

            /*
             Permission was previously denied or restricted.
             Do not attempt to open the camera.
            */
            DispatchQueue.main.async {
                completion(false)
            }

        @unknown default:

            DispatchQueue.main.async {
                completion(false)
            }
        }
    }

    // MARK: - Camera Permission Error

    private func sendCameraPermissionError() {

        let error = NSError(
            domain: "OSCamera",
            code: 1001,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Camera permission was denied. Please allow camera access in Settings."
            ]
        )

        self.sendResult(
            error: error,
            callBackID: self.callbackId
        )
    }

    // MARK: - Edit Picture

    @objc(editPicture:)
    func editPicture(command: CDVInvokedUrlCommand) {

        self.callbackId = command.callbackId

        guard let imageBase64 = command.argument(
            at: 0
        ) as? String,

        let imageData = Data(
            base64Encoded: imageBase64
        ),

        let image = UIImage(
            data: imageData
        )

        else {
            self.callback(
                error: .invalidImageData
            )

            return
        }

        self.commandDelegate.run { [weak self] in

            guard let self = self else {
                return
            }

            self.plugin?.editPicture(image)
        }
    }

    // MARK: - Edit URI Picture

    @objc(editURIPicture:)
    func editURIPicture(
        command: CDVInvokedUrlCommand
    ) {

        self.callbackId = command.callbackId

        guard let parametersDictionary =
                command.argument(at: 0) as? [String: Any],

              let parametersData =
                try? JSONSerialization.data(
                    withJSONObject: parametersDictionary
                ),

              let parameters =
                try? JSONDecoder().decode(
                    OSCAMREditPictureParameters.self,
                    from: parametersData
                )

        else {
            self.callback(
                error: .editPictureIssue
            )

            return
        }

        let options = OSCAMREditOptions(
            from: parameters
        )

        self.commandDelegate.run { [weak self] in

            guard let self = self else {
                return
            }

            self.plugin?.editPicture(
                from: parameters.uri,
                with: options
            )
        }
    }

    // MARK: - Record Video

    @objc(recordVideo:)
    func recordVideo(
        command: CDVInvokedUrlCommand
    ) {

        self.callbackId = command.callbackId

        guard let parametersDictionary =
                command.argument(at: 0) as? [String: Bool],

              let parametersData =
                try? JSONSerialization.data(
                    withJSONObject: parametersDictionary
                ),

              let parameters =
                try? JSONDecoder().decode(
                    OSCAMRRecordVideoParameters.self,
                    from: parametersData
                )

        else {
            self.callback(
                error: .captureVideoIssue
            )

            return
        }

        let options = OSCAMRVideoOptions(
            from: parameters
        )

        self.commandDelegate.run { [weak self] in

            guard let self = self else {
                return
            }

            self.plugin?.captureMedia(
                with: options
            )
        }
    }

    // MARK: - Choose Single Picture

    func chooseSinglePicture(
        allowEdit: Bool
    ) {

        self.commandDelegate.run { [weak self] in

            guard let self = self else {
                return
            }

            self.plugin?.choosePicture(
                allowEdit
            )
        }
    }

    // MARK: - Choose From Gallery

    @objc(chooseFromGallery:)
    func chooseFromGallery(
        command: CDVInvokedUrlCommand
    ) {

        self.callbackId = command.callbackId

        guard let parameterDictionary =
                command.argument(at: 0) as? [String: Any],

              let parameterData =
                try? JSONSerialization.data(
                    withJSONObject: parameterDictionary
                ),

              let parameters =
                try? JSONDecoder().decode(
                    OSCAMRChooseGalleryParameters.self,
                    from: parameterData
                )

        else {
            self.callback(
                error: .chooseMultimediaIssue
            )

            return
        }

        self.commandDelegate.run { [weak self] in

            guard let self = self else {
                return
            }

            self.plugin?.chooseMultimedia(
                parameters.mediaType,
                parameters.allowMultipleSelection,
                parameters.includeMetadata,
                and: parameters.allowEdit
            )
        }
    }

    // MARK: - Play Video

    @objc(playVideo:)
    func playVideo(
        command: CDVInvokedUrlCommand
    ) {

        self.callbackId = command.callbackId

        guard let parameterDictionary =
                command.argument(at: 0) as? [String: Any],

              let parameterData =
                try? JSONSerialization.data(
                    withJSONObject: parameterDictionary
                ),

              let parameters =
                try? JSONDecoder().decode(
                    OSCAMRPlayVideoParameters.self,
                    from: parameterData
                )

        else {
            self.callback(
                error: .playVideoIssue
            )

            return
        }

        self.commandDelegate.run { [weak self] in

            guard let self = self else {
                return
            }

            Task {

                do {

                    try await self.plugin?.playVideo(
                        parameters.url
                    )

                    self.callbackSuccess()

                } catch let error as OSCAMRError {

                    self.callback(
                        error: error
                    )

                } catch {

                    self.callback(
                        error: .playVideoIssue
                    )
                }
            }
        }
    }

    // MARK: - Send Result

    private func sendResult(
        result: String? = nil,
        error: NSError? = nil,
        callBackID: String
    ) {

        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        if let error = error {

            let errorDict = [
                "code":
                    "OS-PLUG-CAMR-\(String(format: "%04d", error.code))",

                "message":
                    error.localizedDescription
            ]

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_ERROR,
                messageAs: errorDict
            )

        } else if let result = result {

            pluginResult =
                result.isEmpty

                ? CDVPluginResult(
                    status: CDVCommandStatus_OK
                )

                : CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: result
                )
        }

        self.commandDelegate.send(
            pluginResult,
            callbackId: callBackID
        )
    }
}

// MARK: - OSCAMRCallbackDelegate

extension OSCamera: OSCAMRCallbackDelegate {

    func callback(
        result: String?,
        error: OSCAMRError?
    ) {

        if let error = error as? NSError {

            self.sendResult(
                error: error,
                callBackID: self.callbackId
            )

        } else if let result = result {

            self.sendResult(
                result: result,
                callBackID: self.callbackId
            )
        }
    }

    func callback(
        error: OSCAMRError
    ) {

        self.callback(
            result: nil,
            error: error
        )
    }

    func callback(
        _ result: String
    ) {

        self.callback(
            result: result,
            error: nil
        )
    }

    func callbackSuccess() {

        self.callback("")
    }
}
