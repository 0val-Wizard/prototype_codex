import ARKit
import RealityKit
import SwiftUI
import UIKit

struct ARViewContainer: UIViewRepresentable {
    let products: [Product]
    let selectedProductID: String?
    let placementRequestID: UUID
    let onPlaneDetectionChanged: (Bool) -> Void
    let onModelSelected: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPlaneDetectionChanged: onPlaneDetectionChanged,
            onModelSelected: onModelSelected
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        arView.environment.background = .color(.black)
        arView.session.delegate = context.coordinator
        arView.session.run(configuration)

        context.coordinator.arView = arView
        context.coordinator.installInteractions(on: arView)
        context.coordinator.installCoachingOverlay(on: arView)
        context.coordinator.update(products: products, selectedProductID: selectedProductID, placementRequestID: placementRequestID)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.arView = uiView
        context.coordinator.update(products: products, selectedProductID: selectedProductID, placementRequestID: placementRequestID)
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?

        private let onPlaneDetectionChanged: (Bool) -> Void
        private let onModelSelected: (String) -> Void

        private var latestProducts: [Product] = []
        private var selectedProductID: String?
        private var planeAnchorTransform: simd_float4x4?
        private var hasDetectedPlane = false
        private var lastPlacementRequestID: UUID?
        private var placedRootAnchors: [AnchorEntity] = []
        private var placedEntitiesByProductID: [String: ModelEntity] = [:]
        private var entityToProductID: [ObjectIdentifier: String] = [:]
        private var modelPrototypeCache: [String: ModelEntity] = [:]

        init(
            onPlaneDetectionChanged: @escaping (Bool) -> Void,
            onModelSelected: @escaping (String) -> Void
        ) {
            self.onPlaneDetectionChanged = onPlaneDetectionChanged
            self.onModelSelected = onModelSelected
        }

        func installInteractions(on arView: ARView) {
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tapRecognizer)
        }

        func installCoachingOverlay(on arView: ARView) {
            let coachingOverlay = ARCoachingOverlayView()
            coachingOverlay.session = arView.session
            coachingOverlay.goal = .horizontalPlane
            coachingOverlay.activatesAutomatically = true
            coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
            arView.addSubview(coachingOverlay)

            NSLayoutConstraint.activate([
                coachingOverlay.topAnchor.constraint(equalTo: arView.topAnchor),
                coachingOverlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
                coachingOverlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
                coachingOverlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
            ])
        }

        func update(products: [Product], selectedProductID: String?, placementRequestID: UUID) {
            latestProducts = Array(products.prefix(4))
            self.selectedProductID = selectedProductID
            highlightSelection()

            guard lastPlacementRequestID != placementRequestID else { return }
            lastPlacementRequestID = placementRequestID
            placeProductsIfPossible()
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .horizontal else {
                    continue
                }

                let transform = planeAnchor.transform
                DispatchQueue.main.async {
                    self.planeAnchorTransform = transform
                    if !self.hasDetectedPlane {
                        self.hasDetectedPlane = true
                        self.onPlaneDetectionChanged(true)
                    }
                    self.placeProductsIfPossible()
                }
                break
            }
        }

        @objc
        private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = recognizer.location(in: arView)

            if let entity = arView.entity(at: location),
               let productID = entityToProductID[ObjectIdentifier(entity)] ?? productIDFromParentChain(entity)
            {
                DispatchQueue.main.async {
                    self.onModelSelected(productID)
                }
            }
        }

        private func productIDFromParentChain(_ entity: Entity) -> String? {
            var current: Entity? = entity
            while let entity = current {
                if let productID = entityToProductID[ObjectIdentifier(entity)] {
                    return productID
                }
                current = entity.parent
            }
            return nil
        }

        private func placeProductsIfPossible() {
            guard let arView, let planeAnchorTransform else { return }
            guard latestProducts.count == 4 else { return }

            clearPlacedModels(from: arView)

            let offsets: [SIMD3<Float>] = [
                SIMD3<Float>(-0.18, 0, -0.12),
                SIMD3<Float>(0.18, 0, -0.12),
                SIMD3<Float>(-0.18, 0, 0.12),
                SIMD3<Float>(0.18, 0, 0.12)
            ]

            for (index, product) in latestProducts.enumerated() {
                let anchor = AnchorEntity(world: planeAnchorTransform)
                let position = offsets[index]
                let entity = buildDisplayModel(for: product)
                entity.position = [position.x, 0.02, position.z]
                anchor.addChild(entity)
                arView.scene.addAnchor(anchor)

                placedRootAnchors.append(anchor)
                placedEntitiesByProductID[product.id] = entity
                registerEntityTree(entity, productID: product.id)
            }

            highlightSelection()
        }

        private func clearPlacedModels(from arView: ARView) {
            for anchor in placedRootAnchors {
                arView.scene.removeAnchor(anchor)
            }
            placedRootAnchors.removeAll()
            placedEntitiesByProductID.removeAll()
            entityToProductID.removeAll()
        }

        private func buildDisplayModel(for product: Product) -> ModelEntity {
            if let prototype = modelPrototypeCache[product.modelName] {
                let clone = prototype.clone(recursive: true)
                clone.scale = SIMD3<Float>(repeating: 0.18)
                return clone
            }

            if let loaded = try? ModelEntity.loadModel(named: product.modelName) {
                loaded.generateCollisionShapes(recursive: true)
                loaded.scale = SIMD3<Float>(repeating: 0.18)
                modelPrototypeCache[product.modelName] = loaded

                let clone = loaded.clone(recursive: true)
                clone.scale = SIMD3<Float>(repeating: 0.18)
                return clone
            }

            let group = ModelEntity()
            let accent = UIColor(hex: product.accentHex)

            let base = ModelEntity(
                mesh: .generateBox(size: [0.18, 0.01, 0.12], cornerRadius: 0.004),
                materials: [SimpleMaterial(color: .darkGray, roughness: 0.8, isMetallic: false)]
            )
            base.position = [0, 0.005, 0]

            let stand = ModelEntity(
                mesh: .generateBox(size: [0.018, 0.10, 0.018], cornerRadius: 0.004),
                materials: [SimpleMaterial(color: accent.withAlphaComponent(0.92), roughness: 0.3, isMetallic: false)]
            )
            stand.position = [0, 0.06, 0]

            let screen = ModelEntity(
                mesh: .generateBox(size: [0.22, 0.13, 0.018], cornerRadius: 0.01),
                materials: [SimpleMaterial(color: accent, roughness: 0.2, isMetallic: false)]
            )
            screen.position = [0, 0.14, -0.01]

            let bezel = ModelEntity(
                mesh: .generateBox(size: [0.20, 0.11, 0.01], cornerRadius: 0.008),
                materials: [SimpleMaterial(color: .black, roughness: 0.05, isMetallic: true)]
            )
            bezel.position = [0, 0, 0.01]

            screen.addChild(bezel)
            group.addChild(base)
            group.addChild(stand)
            group.addChild(screen)
            group.generateCollisionShapes(recursive: true)
            return group
        }

        private func registerEntityTree(_ entity: Entity, productID: String) {
            entityToProductID[ObjectIdentifier(entity)] = productID
            for child in entity.children {
                registerEntityTree(child, productID: productID)
            }
        }

        private func highlightSelection() {
            for (productID, entity) in placedEntitiesByProductID {
                applyHighlight(productID == selectedProductID, to: entity)
            }
        }

        private func applyHighlight(_ isSelected: Bool, to entity: Entity) {
            entity.scale = isSelected ? SIMD3<Float>(repeating: 1.08) : SIMD3<Float>(repeating: 1.0)

            for child in entity.children {
                applyHighlight(isSelected, to: child)
            }
        }
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = CGFloat((value & 0xFF0000) >> 16) / 255
        let green = CGFloat((value & 0x00FF00) >> 8) / 255
        let blue = CGFloat(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
