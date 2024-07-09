/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import UIKit
import SceneKit
import ARKit

extension SCNVector3 {
	func length() -> Float {
		return sqrtf(x * x + y * y + z * z)
	}
}

func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
	return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
}

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    // MARK: - IBOutlets

    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
	@IBOutlet weak var resetButton: UIButton!
	@IBOutlet weak var distanceLabel: UILabel!
	
	private var startNode: SCNNode?
	private var endNode: SCNNode?
	private var lineNode: SCNNode?
	
    // MARK: - View Life Cycle
	
	override func viewDidLoad() {
		super.viewDidLoad()
//		let tapGestureRecognizer = UITapGestureRecognizer(
//			target: self,
//			action: #selector(onARSceneViewTapped)
//		)
//		sceneView?.addGestureRecognizer(tapGestureRecognizer)
		
		let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
		sceneView.addGestureRecognizer(panGestureRecognizer)
		
		let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onPlaneTapped(_:)))
		sceneView.addGestureRecognizer(tapGestureRecognizer)
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
	
	private func reset() {
		startNode?.removeFromParentNode()
		startNode = nil
		endNode?.removeFromParentNode()
		endNode = nil
	}
	
	// MARK: - UITapGestureRecognizer
	
	@objc func onPlaneTapped(_ gestureRecognize: UITapGestureRecognizer) {
		let location = gestureRecognize.location(in: sceneView)
		let hitResults = sceneView.hitTest(location, options: [:])
		
		if let hitResult = hitResults.first {
			let node = hitResult.node
			let height = node.boundingBox.max.y - node.boundingBox.min.y
			print("Selected node height 1: \(height)")
		}
		
		if let result = raycastResult(location: location),
		   let anchor = result.anchor,
			let hitTestResultNode = sceneView.node(for: anchor) {
			
			let height = hitTestResultNode.boundingBox.max.y - hitTestResultNode.boundingBox.min.y
			print("Selected node height 2: \(height)")
		}
		
		if let result = raycastResult(location: location),
		   let anchor = result.anchor,
		   let planeAnchor = anchor as? ARPlaneAnchor {
			let height: Float
			if #available(iOS 16.0, *) {
				height = planeAnchor.planeExtent.height
			} else {
				height = planeAnchor.extent.z
			}
			print("Selected node height 3: \(height)")
		}
	}
	
	@objc
	func onARSceneViewTapped(tapGestureRecognizer: UITapGestureRecognizer) {
		if (tapGestureRecognizer.state == .recognized) {
			let location = tapGestureRecognizer.location(in: sceneView)
			if startNode == nil {
				// First tap: Add startNode
				if let result = raycastResult(location: location) {
					startNode = createSphereNode(radius: 0.02, color: .green)
					startNode?.simdTransform = result.worldTransform
					sceneView.scene.rootNode.addChildNode(startNode!)
				}
			} else if endNode == nil {
				// Second tap: Add endNode
				if let result = raycastResult(location: location) {
					endNode = createSphereNode(radius: 0.02, color: .blue)
					endNode?.simdTransform = result.worldTransform
					sceneView.scene.rootNode.addChildNode(endNode!)
					
					let distance = (endNode!.position - startNode!.position).length()
					print(distance)
					distanceLabel.text = String(distance)
					lineNode?.removeFromParentNode()
					lineNode = drawLine(from: startNode!, to: endNode!, length: distance)
				}
			} else {
				// Third and subsequent taps: Update endNode's position
				if let result = raycastResult(location: location) {
					endNode?.simdTransform = result.worldTransform
					let distance = (endNode!.position - startNode!.position).length()
					print(distance)
					distanceLabel.text = String(distance)
					lineNode?.removeFromParentNode()
					lineNode = drawLine(from: startNode!, to: endNode!, length: distance)
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
	
	private func createSphereNode(radius: CGFloat, color: UIColor) -> SCNNode {
		let sphere = SCNSphere(radius: radius)
		let sphereNode = SCNNode(geometry: sphere)
		sphereNode.geometry?.firstMaterial?.diffuse.contents = color
		return sphereNode
	}
	
	private func drawLine(from: SCNNode, to: SCNNode, length: Float) -> SCNNode {
		
		let geometry = SCNCapsule(capRadius: 0.004, height: CGFloat(length))
		geometry.materials.first?.diffuse.contents = UIColor.red
		let line = SCNNode(geometry: geometry)
		
		let lineNode = SCNNode()
		lineNode.eulerAngles = SCNVector3Make(Float.pi/2, 0, 0)
		lineNode.addChildNode(line)
		
		from.addChildNode(lineNode)
		lineNode.position = SCNVector3Make(0, 0, -length / 2)
		from.look(at: to.position)
		
		return lineNode
	}
	
	@objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
		if gesture.state == .changed {
			let location = gesture.location(in: sceneView)
			if let result = raycastResult(location: location) {
				// Check if there's an existing ARAnchor with the same name
				if let existingAnchor = sceneView.session.currentFrame?.anchors.first(where: { $0.name == "virtualObject" }) {
					// Update the existing ARAnchor's transform based on the raycast result
					let newTransform = result.worldTransform // Use the worldTransform from ARRacastResult
					
				}
			}
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
			guard let planeAnchor = anchor as? ARPlaneAnchor,
				  planeAnchor.alignment == .vertical else { return }
			
			// Create a custom object to visualize the plane geometry and extent.
			let plane = Plane(anchor: planeAnchor, in: sceneView)
			
			// Add the visualization to the ARKit-managed node so that it tracks
			// changes in the plane anchor as plane estimation continues.
			node.addChildNode(plane)
			
//			guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//			if planeAnchor.alignment == .vertical {
//				let planeNode = CustomPlane(anchor: planeAnchor)
//				node.addChildNode(planeNode)
//			}
		}
	}

    /// - Tag: UpdateARContent
	func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
		// Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
		guard let planeAnchor = anchor as? ARPlaneAnchor,
			  planeAnchor.alignment == .vertical,
			  let plane = node.childNodes.first as? Plane else { return }
		
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
				classificationGeometry.string = currentClassification + " Height: \(planeAnchor.extent.z)"
				classificationNode.centerAlign()
			}
		}
		
		// Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
//		guard let planeAnchor = anchor as? ARPlaneAnchor,
//			planeAnchor.alignment == .vertical,
//			let plane = node.childNodes.first as? CustomPlane
//			else { return }
//		
//		if let planeGeometry = plane.geometry as? ARSCNPlaneGeometry {
//			planeGeometry.update(from: planeAnchor.geometry)
//		}
//		
//		if let planeGeometry = plane.geometry as? SCNPlane {
//			planeGeometry.width = CGFloat(planeAnchor.extent.x)
//			planeGeometry.height = CGFloat(planeAnchor.extent.z)
//			plane.simdPosition = planeAnchor.center
//		}
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
	
	
	@IBAction func resetButtonTapped(_ sender: Any) {
		reset()
	}
}
