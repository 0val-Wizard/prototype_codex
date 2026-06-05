import ARKit
import RealityKit
import SwiftUI
import UIKit

struct ARPreviewContainer: UIViewRepresentable {
    let selectedProduct: ProductRecommendation?
    let placedAnchors: [PlacedProductAnchor]
    let onTapPlacement: (simd_float4x4) -> Void
    let onSceneMessage: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapPlacement: onTapPlacement, onSceneMessage: onSceneMessage)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        view.environment.background = .color(.black)
        view.session.run(configuration)
        context.coordinator.arView = view
        context.coordinator.installInteractions(on: view)
        context.coordinator.installCoachingOverlay(on: view)
        context.coordinator.updateScene(selectedProduct: selectedProduct, placedAnchors: placedAnchors)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.arView = uiView
        context.coordinator.onTapPlacement = onTapPlacement
        context.coordinator.onSceneMessage = onSceneMessage
        context.coordinator.updateScene(selectedProduct: selectedProduct, placedAnchors: placedAnchors)
    }

    final class Coordinator: NSObject {
        weak var arView: ARView?
        var onTapPlacement: (simd_float4x4) -> Void
        var onSceneMessage: (String) -> Void

        private var selectedProduct: ProductRecommendation?
        private var lastSelectedProductID: String?
        private var anchorEntities: [UUID: AnchorEntity] = [:]

        init(
            onTapPlacement: @escaping (simd_float4x4) -> Void,
            onSceneMessage: @escaping (String) -> Void
        ) {
            self.onTapPlacement = onTapPlacement
            self.onSceneMessage = onSceneMessage
        }

        func installInteractions(on view: ARView) {
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            view.addGestureRecognizer(tapRecognizer)
        }

        func installCoachingOverlay(on view: ARView) {
            let coachingView = ARCoachingOverlayView()
            coachingView.session = view.session
            coachingView.goal = .horizontalPlane
            coachingView.activatesAutomatically = true
            coachingView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(coachingView)

            NSLayoutConstraint.activate([
                coachingView.topAnchor.constraint(equalTo: view.topAnchor),
                coachingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                coachingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                coachingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        func updateScene(selectedProduct: ProductRecommendation?, placedAnchors: [PlacedProductAnchor]) {
            self.selectedProduct = selectedProduct
            syncAnchors(with: placedAnchors)

            let selectedID = selectedProduct?.id
            guard selectedID != lastSelectedProductID else { return }
            lastSelectedProductID = selectedID

            if let selectedProduct {
                onSceneMessage("Tap a detected surface to place \(selectedProduct.product.title).")
            } else {
                onSceneMessage("Choose a recommendation before placing it in AR.")
            }
        }

        @objc
        private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            guard selectedProduct != nil else {
                onSceneMessage("Select a recommendation first.")
                return
            }

            let location = recognizer.location(in: arView)
            let results = arView.raycast(
                from: location,
                allowing: .estimatedPlane,
                alignment: .any
            )

            guard let result = results.first else {
                onSceneMessage("Move the device until a surface is detected, then tap again.")
                return
            }

            onTapPlacement(result.worldTransform)
        }

        private func syncAnchors(with placedAnchors: [PlacedProductAnchor]) {
            guard let arView else { return }

            let nextIDs = Set(placedAnchors.map(\.id))
            let currentIDs = Set(anchorEntities.keys)

            for removedID in currentIDs.subtracting(nextIDs) {
                if let entity = anchorEntities.removeValue(forKey: removedID) {
                    arView.scene.removeAnchor(entity)
                }
            }

            for placedAnchor in placedAnchors where anchorEntities[placedAnchor.id] == nil {
                let anchorEntity = buildAnchor(for: placedAnchor)
                anchorEntities[placedAnchor.id] = anchorEntity
                arView.scene.addAnchor(anchorEntity)
            }
        }

        private func buildAnchor(for placedAnchor: PlacedProductAnchor) -> AnchorEntity {
            let anchor = AnchorEntity(world: placedAnchor.transform)
            let recommendation = placedAnchor.recommendation
            let color = UIColor(category: recommendation.product.category)

            let pedestal = ModelEntity(
                mesh: .generateBox(size: [0.22, 0.02, 0.22], cornerRadius: 0.01),
                materials: [SimpleMaterial(color: .darkGray.withAlphaComponent(0.85), roughness: 0.7, isMetallic: false)]
            )
            pedestal.position = [0, 0.01, 0]

            let productBody = ModelEntity(
                mesh: .generateBox(size: [0.14, 0.14, 0.14], cornerRadius: 0.02),
                materials: [SimpleMaterial(color: color, roughness: 0.25, isMetallic: false)]
            )
            productBody.position = [0, 0.10, 0]

            let marker = ModelEntity(
                mesh: .generateSphere(radius: 0.015),
                materials: [SimpleMaterial(color: .white, roughness: 0.1, isMetallic: true)]
            )
            marker.position = [0.09, 0.18, 0]

            anchor.addChild(pedestal)
            anchor.addChild(productBody)
            anchor.addChild(marker)
            return anchor
        }
    }
}

private extension UIColor {
    convenience init(category: ProductCategory) {
        switch category {
        case .homeRepair:
            self.init(red: 0.23, green: 0.74, blue: 0.92, alpha: 1)
        case .beauty:
            self.init(red: 0.95, green: 0.49, blue: 0.66, alpha: 1)
        case .fashion:
            self.init(red: 0.45, green: 0.46, blue: 0.97, alpha: 1)
        case .electronics:
            self.init(red: 0.45, green: 0.89, blue: 0.72, alpha: 1)
        case .grocery:
            self.init(red: 0.92, green: 0.73, blue: 0.33, alpha: 1)
        case .homeDecor:
            self.init(red: 0.73, green: 0.60, blue: 0.96, alpha: 1)
        case .general:
            self.init(white: 0.8, alpha: 1)
        }
    }
}
