/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import UIKit
import SceneKit
import ARKit

extension CGPoint {
	func distance2DFrom(_ otherPoint: CGPoint) -> Double {
		return sqrt(pow((otherPoint.x - self.x), 2) + pow((otherPoint.y - self.y), 2))
	}
}

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    // MARK: - IBOutlets

    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!

	private let centerAllowedTapRadius: Double = 120
	
    // MARK: - View Life Cycle
	
	override func viewDidLoad() {
		super.viewDidLoad()
		let tapGestureRecognizer = UITapGestureRecognizer(
			target: self,
			action: #selector(onARSceneViewTapped)
		)
		sceneView?.addGestureRecognizer(tapGestureRecognizer)
		
		let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
		sceneView.addGestureRecognizer(panGestureRecognizer)
	}

    /// - Tag: StartARSession
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Start the view's AR session with a configuration that uses the rear camera,
        // device position and orientation tracking, and plane detection.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration)

        // Set a delegate to track the number of plane anchors for providing UI feedback.
        sceneView.session.delegate = self
        
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Show debug UI to view performance metrics (e.g. frames per second).
        sceneView.showsStatistics = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's AR session.
        sceneView.session.pause()
    }
	
	// MARK: - UITapGestureRecognizer
	
	@objc
	func onARSceneViewTapped(tapGestureRecognizer: UITapGestureRecognizer) {
		if (tapGestureRecognizer.state == .recognized) {
			let tapPoint = tapGestureRecognizer.location(in: sceneView)
			tryPlacingMarker1(location: tapPoint)
//			if (tapPoint.distance2DFrom(sceneView.center) <= centerAllowedTapRadius) {
//				tryPlacingMarker1(location: tapPoint)
//			}
		}
	}
	
	@objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
		if gesture.state == .changed {
			let location = gesture.location(in: sceneView)
			if let result = raycastResult(location: location) {
				// Check if there's an existing ARAnchor with the same name
				if let existingAnchor = sceneView.session.currentFrame?.anchors.first(where: { $0.name == "virtualObject" }) {
					// Update the existing ARAnchor's transform based on the raycast result
					let newTransform = result.worldTransform // Use the worldTransform from ARRacastResult
					
					// Remove the existing anchor and add the updated anchor back to the session
//					sceneView.session.remove(anchor: existingAnchor)
//					sceneView.session.add(anchor: ARAnchor(name: "virtualObject", transform: newTransform))
					
				}
			}
		}
	}
	
	// Mark at tap location
	private func tryPlacingMarker1(location: CGPoint) {
		if let result = raycastResult(location: location) {
			// Place a virtual object at the raycast result position
			if let existingAnchor = sceneView.session.currentFrame?.anchors.first(where: { $0.name == "virtualObject" }) {
				// Update the existing ARAnchor's transform based on the raycast result
				var newTransform = existingAnchor.transform
				newTransform = result.worldTransform // Use the worldTransform from ARRacastResult
				
				// Remove the existing anchor and add the updated anchor back to the session
				sceneView.session.remove(anchor: existingAnchor)
				sceneView.session.add(anchor: ARAnchor(name: "virtualObject", transform: newTransform))
			} else {
				// If there's no existing anchor, create a new one at the tapped location
				let newAnchor = ARAnchor(name: "virtualObject", transform: result.worldTransform)
				sceneView.session.add(anchor: newAnchor)
			}
		}
	}
	
	private func raycastResult(location: CGPoint) -> ARRaycastResult? {
		if let query = sceneView.raycastQuery(from: location, allowing: .existingPlaneGeometry, alignment: .any),
		   let result = sceneView.session.raycast(query).first {
			return result
		} else {
			return nil
		}
	}

    // MARK: - ARSCNViewDelegate
	
	/// - Tag: PlaceARContent
	func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
		if anchor.name == "virtualObject" {
			let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.05))
			sphereNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
			node.addChildNode(sphereNode)
		} else {
			// Place content only for anchors found by plane detection.
			guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
			
			// Create a custom object to visualize the plane geometry and extent.
			let plane = Plane(anchor: planeAnchor, in: sceneView)
			
			// Add the visualization to the ARKit-managed node so that it tracks
			// changes in the plane anchor as plane estimation continues.
			node.addChildNode(plane)
		}
	}

    /// - Tag: UpdateARContent
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first as? Plane
            else { return }
        
        // Update ARSCNPlaneGeometry to the anchor's new estimated shape.
        if let planeGeometry = plane.meshNode.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: planeAnchor.geometry)
        }

        // Update extent visualization to the anchor's new bounding rectangle.
        if let extentGeometry = plane.extentNode.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(planeAnchor.extent.x)
            extentGeometry.height = CGFloat(planeAnchor.extent.z)
            plane.extentNode.simdPosition = planeAnchor.center
        }
		
		// Update the plane's classification and the text position
		if let classificationNode = plane.classificationNode,
		   let classificationGeometry = classificationNode.geometry as? SCNText {
			let currentClassification = planeAnchor.classification.description
			if let oldClassification = classificationGeometry.string as? String, oldClassification != currentClassification {
				classificationGeometry.string = currentClassification
				classificationNode.centerAlign()
			}
		}
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }

    // MARK: - ARSessionObserver

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay.
        sessionInfoLabel.text = "Session was interrupted"
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        sessionInfoLabel.text = "Session interruption ended"
        resetTracking()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetTracking()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    // MARK: - Private methods

    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String

        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move the device around to detect horizontal and vertical surfaces."
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            message = ""

        }

        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }

    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}
