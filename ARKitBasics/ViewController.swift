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
		guard let sceneView = sceneView else { return }
		if (tapGestureRecognizer.state == .recognized) {
			let tapPoint = tapGestureRecognizer.location(in: sceneView)
			if (tapPoint.distance2DFrom(sceneView.center) <= centerAllowedTapRadius) {
				tryPlacingMarker2(location: tapPoint)
			}
		}
	}
	
	// Mark at tap location
	private func tryPlacingMarker1(location: CGPoint) {
		if let query = sceneView.raycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: .any),
		   let result = sceneView.session.raycast(query).first {
			// Place a virtual object at the raycast result position
			let anchor = ARAnchor(name: "virtualObject", transform: result.worldTransform)
			sceneView.session.add(anchor: anchor)
		}
	}
	
	// Mark at center horizontal location
	private func tryPlacingMarker2(location: CGPoint) {
		if let result = smartRaycastResultForViewCenter() {
			// Place a virtual object at the raycast result position
			let anchor = ARAnchor(name: "virtualObject", transform: result.worldTransform)
			sceneView.session.add(anchor: anchor)
		}
	}
	
	private func smartRaycastResultForViewCenter() -> ARRaycastResult? {
		let currentTaskAnchorAlignment: ARPlaneAnchor.Alignment = .horizontal
		let existingPlaneGeometryResults = raycastResultsForViewCenter(allowing: .existingPlaneGeometry)
		
		if let firstExistingPlaneGeometryResult = existingPlaneGeometryResults.first,
		   let planeAnchor = (firstExistingPlaneGeometryResult.anchor as? ARPlaneAnchor),
		   planeAnchor.alignment == currentTaskAnchorAlignment {
			return firstExistingPlaneGeometryResult
		}
		return nil
	}
	
	private func raycastResultsForViewCenter(allowing targetType: ARRaycastQuery.Target) -> [ARRaycastResult] {
		guard let sceneView = sceneView,
			  let query = sceneView.raycastQuery(
				from: sceneView.center,
				allowing: targetType,
				alignment: .horizontal
			  )
		else { return [] }
		return sceneView.session.raycast(query)
	}
	
	private func findIntersectionBetween(planeAnchor: ARPlaneAnchor, otherPlaneAnchor: ARPlaneAnchor) -> SCNVector3? {
		// Get the vertices of the first plane
		let planeVertices = getPlaneVertices(anchor: planeAnchor)
		// Get the vertices of the second plane
		let otherPlaneVertices = getPlaneVertices(anchor: otherPlaneAnchor)
		
		// Check each vertex of the first plane against each vertex of the second plane
		for vertex in planeVertices {
			for otherVertex in otherPlaneVertices {
				let distance = simd_distance(vertex, otherVertex)
				if distance < 0.1 { // 임계값을 원하는 값으로 조정
					// 두 꼭짓점이 가까운 경우 해당 위치를 반환
					return SCNVector3((vertex.x + otherVertex.x) / 2, (vertex.y + otherVertex.y) / 2, (vertex.z + otherVertex.z) / 2)
				}
			}
		}
		return nil
	}
	
	func getPlaneVertices(anchor: ARPlaneAnchor) -> [simd_float3] {
		let center = anchor.center
		let extent = anchor.extent
		print(anchor.alignment, center, extent)

		let topLeft = simd_float3(center.x - extent.x / 2, 0, center.z - extent.z / 2)
		let topRight = simd_float3(center.x + extent.x / 2, 0, center.z - extent.z / 2)
		let bottomLeft = simd_float3(center.x - extent.x / 2, 0, center.z + extent.z / 2)
		let bottomRight = simd_float3(center.x + extent.x / 2, 0, center.z + extent.z / 2)

		return [topLeft, topRight, bottomLeft, bottomRight]
	}

    // MARK: - ARSCNViewDelegate
	
//	func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
//		if #available(iOS 13.0, *) {
//			if anchor.name == "virtualObject" {
//				let node = SCNNode()
//				node.geometry = SCNSphere(radius: 0.1)
//				node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
//				return node
//			}
//		}
//		return nil
//	}
	
	/// - Tag: PlaceARContent
	func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
		if anchor.name == "virtualObject" {
			let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.1))
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
		
		if let otherPlaneAnchors = sceneView.session.currentFrame?.anchors.compactMap({ $0 as? ARPlaneAnchor }), otherPlaneAnchors.count > 1 {
			for otherAnchor in otherPlaneAnchors where otherAnchor != planeAnchor {
				if let intersection = findIntersectionBetween(planeAnchor: planeAnchor, otherPlaneAnchor: otherAnchor) {
					let sphere = SCNSphere(radius: 0.05)
					sphere.firstMaterial?.diffuse.contents = UIColor.green
					let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.05))
					sphereNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
					sphereNode.position = intersection
					sceneView.scene.rootNode.addChildNode(sphereNode)
				}
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
