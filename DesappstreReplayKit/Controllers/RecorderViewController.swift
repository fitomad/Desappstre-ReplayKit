import UIKit
import Foundation
import ReplayKit
import AudioToolbox

internal class RecorderViewController: UIViewController
{
    /// Estado de los botones
    private enum Status
    {
        case on
        case off
    }

    /// Aquí mostramos las imágenes de la cámara
    @IBOutlet private weak var viewFrontCamera: UIView!
    /// Inicio o detine la grabación
    @IBOutlet private weak var buttonRecord: UIButton!
    /// Activa o desactiva el micrófono
    @IBOutlet private weak var buttonMicrophone: UIButton!
    /// Activa o desactiva la cámara
    @IBOutlet private weak var buttonCamera: UIButton!
    /// Emisión en vivo
    @IBOutlet private weak var buttonGoLive: UIButton!

    /// Si estamos grabado la pantalla o no
    private var isScreenRecording: Bool!
    {
        didSet
        {
            let status = self.isScreenRecording ? RecorderViewController.Status.on : RecorderViewController.Status.off
            self.toogleButton(self.buttonRecord, to: status)
        }
    }

    /// El controlador de broadcasting
    private var broadcastController: RPBroadcastController?
    {
        didSet
        {
            self.broadcastController?.delegate = self
        }
    }

    //
    // MARK: - Life Cycle
    //

    /**
        Nos preparamos...
    */
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
        Preparamos el interface de usuario
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
        
        self.buttonCamera.tintColor = RPScreenRecorder.shared().isCameraEnabled ? UIColor(named: "EnableColor") : UIColor(named: "DisableColor")
        self.buttonGoLive.tintColor = UIColor(named: "DisableColor")
        self.buttonMicrophone.tintColor = UIColor(named: "DisableColor")
    }

    //
    // MARK: - Animations
    //

    /**
        Muestra los botones de control de la grabación
        como activados o desactivados
    */
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
        Animación para los botones de colores.

        Los pone transparente o sin transparencia
    */
    private func animateButton(_ button: UIButton, alphaChangeTo alpha: CGFloat) -> Void
    {
        let animator = UIViewPropertyAnimator(duration: 0.25, curve: .easeIn)

        animator.addAnimations() {
            button.alpha = alpha
        }

        animator.startAnimation()
    }

    //
    // MARK: Actions
    //

    /**
        Controla la grabación de pantalla
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
        Activa o desactiva el micrófono.

        Una vez comenzada la grabación no se puede modificar.
    */
    @IBAction private func handleMicrophoneButtonTap(sender: UIButton) -> Void
    {
        guard !RPScreenRecorder.shared().isRecording else
        {
            return
        }
        
        RPScreenRecorder.shared().isMicrophoneEnabled.toggle()
        
        let status = RPScreenRecorder.shared().isMicrophoneEnabled ? RecorderViewController.Status.on : RecorderViewController.Status.off
        self.toogleButton(sender, to: status)
    }

    /**
        Activa o desactiva la cámara.

        Una vez comenzada la grabación no se puede modificar.
    */
    @IBAction private func handleCameraButtonTap(sender: UIButton) -> Void
    {
        guard !RPScreenRecorder.shared().isRecording else
        {
            return
        }
        
        RPScreenRecorder.shared().isCameraEnabled.toggle()

        let status = RPScreenRecorder.shared().isCameraEnabled ? RecorderViewController.Status.on : RecorderViewController.Status.off
        self.toogleButton(sender, to: status)
        
        if !RPScreenRecorder.shared().isCameraEnabled
        {
            self.viewFrontCamera.subviews.forEach({ $0.removeFromSuperview() })
        }
    }

    /**
        Activa o desactiva la emisión en directo
    */
    @IBAction private func handleGoLiveButtonTap(sender: UIButton) -> Void
    {
        if let broadcastController = self.broadcastController, broadcastController.isBroadcasting
        {
            self.toogleButton(sender, to: .off)
            self.stopScreenBroadcasting()
        }
        else
        {
            self.toogleButton(sender, to: .on)
            self.requestScreenBroadcasting()
        }
    }

    /**
        Acciones sobre los botones de colores.
    */
    @IBAction private func handleColoredButtonTap(sender: UIButton) -> Void
    {
        let newAlpha = sender.alpha == 1.0 ? 0.15 : 1.0
        self.animateButton(sender, alphaChangeTo: CGFloat(newAlpha))

        // Emitimos un sonido
        AudioServicesPlaySystemSound(1104)
    }
}

//
// MARK: - ReplayKit Screen Operations
//

extension RecorderViewController
{
    /**
        Iniciamos la grabación
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
                // Si el usuario ha activa la cámara recogemos 
                // la vista con la imagen y la añadimos a la vista.
                if let cameraPreviewView = RPScreenRecorder.shared().cameraPreviewView, RPScreenRecorder.shared().isCameraEnabled
                {
                    DispatchQueue.main.async
                    {
                        cameraPreviewView.frame = self.viewFrontCamera.bounds
                        self.viewFrontCamera.addSubview(cameraPreviewView)
                    }
                }
                
                print("Recording...")
            }
        }
    }

    /**
        Detenemos la grabación 
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
// MARK: - ReplayKit Broadcast Operations
//

extension RecorderViewController
{
    /**
        Mostramos la *activity view* para que el usuario seleccione el 
        servicio de broadcasting que prefiere usar.

        Se listan aquellos servicios cuya App esté instalada en nuestro
        dispositivo.
    */
    private func requestScreenBroadcasting() -> Void
    {
        RPBroadcastActivityViewController.load(handler: { (activityViewController: RPBroadcastActivityViewController?, error: Error?) -> Void in 
            if let error = error
            {
                print("Error al iniciar la emisión.")
                print(error.localizedDescription)

                self.toogleButton(self.buttonGoLive, to: .off)
            }

            guard let activityViewController = activityViewController else
            {
                return
            }

            if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad 
            {
                activityViewController.modalPresentationStyle = UIModalPresentationStyle.popover
                activityViewController.popoverPresentationController?.sourceRect = CGRect.zero
                activityViewController.popoverPresentationController?.sourceView = self.buttonGoLive
            }

            activityViewController.delegate = self

            self.present(activityViewController, animated: true, completion: nil)
        })
    }

    /**
        El usuario ha seleccionado el servicio y comienza
        la emisión
    */
    private func startScreenBroadcasting() -> Void
    {
        guard let broadcastController = self.broadcastController else
        {
            return 
        }

        broadcastController.startBroadcast(handler: { (error: Error?) -> Void in 
            if let error = error
            {
                print("Retransmisión no disponible.")
                print(error.localizedDescription)
            }
            else
            {
                print("Retransmisión disponible en \(broadcastController.broadcastURL.absoluteString)")
            }
        })
    }

    /**
        Terminamos la emisión en directo
    */
    private func stopScreenBroadcasting() -> Void
    {
        guard let broadcastController = self.broadcastController else
        {
            return 
        }

        broadcastController.finishBroadcast(handler: { (error: Error?) -> Void in 
            if let error = error 
            {
                print("Algo pasa al devolver la conexión a nuestros estudio centrales...")
                print(error.localizedDescription)
            }

            self.toogleButton(self.buttonGoLive, to: .off)
        })
    }
}

//
// MARK: - RPPreviewViewControllerDelegate Protocol
//

extension RecorderViewController: RPPreviewViewControllerDelegate
{
    /**
        El usuario ha terminado con la vista de edición de
        la grabación
    */
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) -> Void
    {
        previewController.dismiss(animated: true, completion: nil)
    }

    /**
        El usuario ha terminado con la vista de edición de
        la grabación.

        Podemos ver los activity types.
    */
    func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>) -> Void
    {
        activityTypes.forEach({ (activityType: String) -> Void in
            print(activityType)
        })

        previewController.dismiss(animated: true, completion: nil)
    }
}

//
// MARK: - RPBroadcastActivityViewControllerDelegate Protocol
//

extension RecorderViewController: RPBroadcastActivityViewControllerDelegate
{
    /**
        El usuario acaba de seleccionar uno de los servicios
        de broadcasting que tiene instalados en su equipo.

        Nos devuelve un objeto `RPBroadcastController` con el que 
        se controla la emisión en vivo.
    */
    func broadcastActivityViewController(_ broadcastActivityViewController: RPBroadcastActivityViewController, didFinishWith broadcastController: RPBroadcastController?, error: Error?) -> Void
    {
        if let error = error
        {
            print("Cerrando la selección de servicios de broadcasting...")
            print(error.localizedDescription)
        }

        broadcastActivityViewController.dismiss(animated: true, completion: nil)

        // Guardamos la referencia para poder iniciar 
        // o detener la retransmisión.
        self.broadcastController = broadcastController

        self.startScreenBroadcasting()        
    }
}

//
// MARK: - RPBroadcastControllerDelegate Protocol
//

extension RecorderViewController: RPBroadcastControllerDelegate
{
    /**
        Parece que ha habido un error durante la emisión...
    */
    func broadcastController(_ broadcastController: RPBroadcastController, didFinishWithError error: Error?) -> Void
    {
        if let error = error
        {
            print("Error durante la retransmisión.")
            print(error.localizedDescription)
        }
    }

    /**
        Se ha actualizado la URL de la emisión
    */
    func broadcastController(_ broadcastController: RPBroadcastController, didUpdateBroadcast broadcastURL: URL) -> Void
    {
        print("Nueva URL, retransmisión ahora disponible en \(broadcastURL.absoluteString)")
    }
}
