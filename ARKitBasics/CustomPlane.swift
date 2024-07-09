//
//  CustomPlane.swift
//  ARKitBasics
//
//  Created by Jongho Lee on 6/24/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import ARKit
import SceneKit

class CustomPlane: SCNNode {
	
	init(anchor: ARPlaneAnchor) {
		super.init()
		
		let width = CGFloat(anchor.extent.x)
		let height = CGFloat(anchor.extent.z)
		let planeGeometry = SCNPlane(width: width, height: height)
		
		// Set color and texture based on plane alignment
		switch anchor.alignment {
		case .horizontal:
//			planeGeometry.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.1)
//			planeGeometry.firstMaterial?.diffuse.contents = createGridTexture(color: .blue)
			break
		case .vertical:
			planeGeometry.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.1)
			planeGeometry.firstMaterial?.diffuse.contents = createGridTexture(color: .cyan)
		@unknown default:
			planeGeometry.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.1)
		}
		self.opacity = 0.5
		self.geometry = planeGeometry
		self.eulerAngles.x = -.pi / 2
		self.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func createGridTexture(color: UIColor) -> UIImage? {
		let size: CGFloat = 512
		UIGraphicsBeginImageContext(CGSize(width: size, height: size))
		guard let context = UIGraphicsGetCurrentContext() else { return nil }
		
		context.setStrokeColor(color.cgColor)
		context.setLineWidth(1)
		
		for i in stride(from: 0, to: Int(size), by: 10) {
			context.move(to: CGPoint(x: i, y: 0))
			context.addLine(to: CGPoint(x: i, y: Int(size)))
			context.move(to: CGPoint(x: 0, y: i))
			context.addLine(to: CGPoint(x: Int(size), y: i))
		}
		
		context.strokePath()
		
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		
		return image
	}
}
