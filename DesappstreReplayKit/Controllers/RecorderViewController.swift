import UIKit
import Foundation
import ReplayKit

internal class RecorderViewController: UIViewController
{
    ///
    private enum Status
    {
        case on
        case off
    }

    ///
    @IBOutlet private weak var viewFrontCamera: UIView!
    ///
    @IBOutlet private weak var buttonRecord: UIButton!
    ///
    @IBOutlet private weak var buttonMicrophone: UIButton!
    ///
    @IBOutlet private weak var buttonCamera: UIButton!

    ///
    private var isScreenRecording: Bool!
    {
        didSet
        {
            let status = self.isScreenRecording ? RecorderViewController.Status.on : RecorderViewController.Status.off
            self.toogleButton(self.buttonRecord, to: status)
        }
    }

    //
    // MARK: - Life Cycle
    //

    override internal func viewDidLoad() -> Void
    {
        super.viewDidLoad()

        self.isScreenRecording = false

        self.prepareUI()
    }

    //
    // MARK: - Prepare UI
    //

    /**

    */
    private func prepareUI() -> Void
    {
        self.view.backgroundColor = UIColor(named: "BackgroundColor")
        self.viewFrontCamera.backgroundColor = UIColor(named: "CameraBackgroundColor")

        self.viewFrontCamera.layer.cornerRadius = 8.0
        self.viewFrontCamera.layer.masksToBounds = true
        self.viewFrontCamera.layer.shadowRadius = 20.0
        self.viewFrontCamera.layer.shadowOffset = CGSize.zero
        self.viewFrontCamera.layer.shadowColor = UIColor(named: "ShadowColor")?.cgColor
    }

    //
    // MARK: - Animations
    //

    private func toogleButton(_ button: UIButton, to status: RecorderViewController.Status) -> Void
    {
        guard let enabledColor = UIColor(named: "EnableColor"),
              let disabledColor = UIColor(named: "DisableColor")
        else
        {
            return
        }

        let animator = UIViewPropertyAnimator(duration: 0.35, curve: .easeIn)

        animator.addAnimations() {
            button.tintColor = (status == .on) ? enabledColor : disabledColor
        }

        animator.startAnimation()
    }

    /**

    */
    private func animateButton(_ button: UIButton, alphaChangeTo alpha: CGFloat) -> Void
    {
        let animator = UIViewPropertyAnimator(duration: 0.35, curve: .easeIn)

        animator.addAnimations() {
            button.alpha = alpha
        }

        animator.startAnimation()
    }

    //
    // MARK: Actions
    //

    /**

    */
    @IBAction private func handleRecordButtonTap(sender: UIButton) -> Void
    {
        self.isScreenRecording.toggle()

        if self.isScreenRecording
        {
            self.startScreenRecording()
        }
        else
        {
            self.stopScreenRecording()
        }
    }

    /**

    */
    @IBAction private func handleMicrophoneButtonTap(sender: UIButton) -> Void
    {
        RPScreenRecorder.shared().isMicrophoneEnabled.toggle()

        let status = RPScreenRecorder.shared().isMicrophoneEnabled ? RecorderViewController.Status.on : RecorderViewController.Status.off
        self.toogleButton(sender, to: status)
    }

    /**

    */
    @IBAction private func handleCameraButtonTap(sender: UIButton) -> Void
    {
        RPScreenRecorder.shared().isCameraEnabled.toggle()
        
        if let cameraPreviewView = RPScreenRecorder.shared().cameraPreviewView
        {
            self.viewFrontCamera.addSubview(cameraPreviewView)
        }

        let status = RPScreenRecorder.shared().isCameraEnabled ? RecorderViewController.Status.on : RecorderViewController.Status.off
        self.toogleButton(sender, to: status)
    }

    /**

    */
    @IBAction private func handleColoredButtonTap(sender: UIButton) -> Void
    {
        let newAlpha = sender.alpha == 1.0 ? 0.25 : 1.0
        self.animateButton(sender, alphaChangeTo: CGFloat(newAlpha))
    }
}

//
// MARK: - ReplayKit Operations
//

extension RecorderViewController
{
    /**

    */
    private func startScreenRecording() -> Void
    {
        RPScreenRecorder.shared().startRecording() { (error: Error?) -> Void in 
            if let error = error
            {
                print("Error al empezar a grabar la pantalla.")
                print(error.localizedDescription)

                self.isScreenRecording = false
            }
            else
            {
                print("Recording...")
            }
        }
    }

    /**

    */
    private func stopScreenRecording() -> Void
    {
        RPScreenRecorder.shared().stopRecording() { (previewController: RPPreviewViewController?, error: Error?) -> Void in 
            if let error = error
            {
                print("Error al detener la grabación.")
                print(error.localizedDescription)
            }

            guard let previewController = previewController else
            {
                return
            }
            
            if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad 
            {
                previewController.modalPresentationStyle = UIModalPresentationStyle.popover
                previewController.popoverPresentationController?.sourceRect = CGRect.zero
                previewController.popoverPresentationController?.sourceView = self.buttonRecord
            }

            previewController.previewControllerDelegate = self

            self.present(previewController, animated: true, completion: nil)
        }
    }
}

//
// MARK: - RPPreviewViewControllerDelegate Protocol
//

extension RecorderViewController: RPPreviewViewControllerDelegate
{
    /**

    */
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) -> Void
    {
        previewController.dismiss(animated: true, completion: nil)
    }

    /**

    */
    func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>) -> Void
    {
        activityTypes.forEach({ (activityType: String) -> Void in
            print(activityType)
        })

        previewController.dismiss(animated: true, completion: nil)
    }
}
