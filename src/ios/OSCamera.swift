import OSCameraLib
import AVFoundation

@objc(OSCamera)
class OSCamera: CDVPlugin {

    var plugin: OSCAMRActionDelegate?
    var callbackId: String = ""

    override func pluginInitialize() {

        NSLog("CHRISTIAN CAMERA: pluginInitialize START")

        /*
         IMPORTANT:
         Do NOT initialize OSCAMRFactory here.
        */

        NSLog("CHRISTIAN CAMERA: pluginInitialize END")
    }

    @objc(takePicture:)
    func takePicture(command: CDVInvokedUrlCommand) {

        NSLog("CHRISTIAN CAMERA: takePicture START")

        self.callbackId = command.callbackId

        NSLog("CHRISTIAN CAMERA: callbackId = \(self.callbackId)")

        let status = AVCaptureDevice.authorizationStatus(
            for: .video
        )

        NSLog(
            "CHRISTIAN CAMERA: camera authorization status = \(status.rawValue)"
        )

        switch status {

        case .authorized:

            NSLog("CHRISTIAN CAMERA: CAMERA AUTHORIZED")

            self.testCameraAccess()

        case .notDetermined:

            NSLog("CHRISTIAN CAMERA: CAMERA NOT DETERMINED")

            AVCaptureDevice.requestAccess(
                for: .video
            ) { [weak self] granted in

                DispatchQueue.main.async {

                    NSLog(
                        "CHRISTIAN CAMERA: permission result = \(granted)"
                    )

                    guard let self = self else {
                        return
                    }

                    if granted {

                        self.testCameraAccess()

                    } else {

                        self.sendError(
                            message: "Camera permission was denied."
                        )
                    }
                }
            }

        case .denied:

            NSLog("CHRISTIAN CAMERA: CAMERA DENIED")

            self.sendError(
                message: "Camera permission was denied. Please enable it in Settings."
            )

        case .restricted:

            NSLog("CHRISTIAN CAMERA: CAMERA RESTRICTED")

            self.sendError(
                message: "Camera access is restricted."
            )

        @unknown default:

            NSLog("CHRISTIAN CAMERA: UNKNOWN CAMERA STATUS")

            self.sendError(
                message: "Unknown camera authorization status."
            )
        }
    }

    private func testCameraAccess() {

        NSLog("CHRISTIAN CAMERA: testCameraAccess START")

        DispatchQueue.main.async { [weak self] in

            guard let self = self else {
                return
            }

            NSLog("CHRISTIAN CAMERA: creating AVCaptureDevice")

            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            )

            if let device = device {

                NSLog(
                    "CHRISTIAN CAMERA: CAMERA DEVICE FOUND = \(device)"
                )

                self.sendSuccess(
                    message: "CAMERA_DEVICE_FOUND"
                )

            } else {

                NSLog(
                    "CHRISTIAN CAMERA: CAMERA DEVICE NOT FOUND"
                )

                self.sendError(
                    message: "Camera device was not found."
                )
            }
        }
    }

    private func sendSuccess(message: String) {

        NSLog(
            "CHRISTIAN CAMERA: SUCCESS = \(message)"
        )

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: message
        )

        self.commandDelegate.send(
            result,
            callbackId: self.callbackId
        )
    }

    private func sendError(message: String) {

        NSLog(
            "CHRISTIAN CAMERA: ERROR = \(message)"
        )

        let result = CDVPluginResult(
            status: CDVCommandStatus_ERROR,
            messageAs: [
                "code": "CAMERA_TEST_ERROR",
                "message": message
            ]
        )

        self.commandDelegate.send(
            result,
            callbackId: self.callbackId
        )
    }

    override func onAppTerminate() {

        NSLog(
            "CHRISTIAN CAMERA: onAppTerminate"
        )
    }
}
