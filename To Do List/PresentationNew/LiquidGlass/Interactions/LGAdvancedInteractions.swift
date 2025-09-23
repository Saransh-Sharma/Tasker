// LGAdvancedInteractions.swift
// Advanced interaction system with swipe actions and drag/drop - Phase 4 Implementation
// Glass morphism effects for complex user interactions

import UIKit
import SnapKit

// MARK: - Swipe Actions Controller

class LGSwipeActionsController {
    
    // MARK: - Action Types
    enum ActionType {
        case complete, delete, reschedule, edit
        
        var icon: UIImage? {
            switch self {
            case .complete: return UIImage(systemName: "checkmark.circle.fill")
            case .delete: return UIImage(systemName: "trash.fill")
            case .reschedule: return UIImage(systemName: "calendar")
            case .edit: return UIImage(systemName: "pencil")
            }
        }
        
        var color: UIColor {
            switch self {
            case .complete: return .systemGreen
            case .delete: return .systemRed
            case .reschedule: return .systemOrange
            case .edit: return .systemBlue
            }
        }
        
        var title: String {
            switch self {
            case .complete: return "Complete"
            case .delete: return "Delete"
            case .reschedule: return "Reschedule"
            case .edit: return "Edit"
            }
        }
    }
    
    // MARK: - Properties
    private weak var targetView: UIView?
    private var actionsContainer: LGBaseView?
    private var actionButtons: [LGSwipeActionButton] = []
    private var panGesture: UIPanGestureRecognizer?
    private var initialCenter: CGPoint = .zero
    private var isActionsVisible = false
    
    var onActionTriggered: ((ActionType) -> Void)?
    
    // MARK: - Initialization
    
    init(targetView: UIView, actions: [ActionType]) {
        self.targetView = targetView
        setupSwipeActions(actions)
        setupGestures()
    }
    
    // MARK: - Setup
    
    private func setupSwipeActions(_ actions: [ActionType]) {
        guard let targetView = targetView else { return }
        
        // Create actions container
        actionsContainer = LGBaseView()
        actionsContainer?.glassIntensity = 0.8
        actionsContainer?.cornerRadius = 12
        actionsContainer?.enableGlassBorder = true
        actionsContainer?.isHidden = true
        
        guard let container = actionsContainer else { return }
        
        // Add to parent view
        if let parentView = targetView.superview {
            parentView.insertSubview(container, belowSubview: targetView)
            
            container.snp.makeConstraints { make in
                make.trailing.equalTo(targetView.snp.trailing)
                make.centerY.equalTo(targetView)
                make.height.equalTo(targetView)
                make.width.equalTo(actions.count * 80)
            }
        }
        
        // Create action buttons
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        
        for action in actions {
            let button = LGSwipeActionButton(action: action)
            button.onTap = { [weak self] in
                self?.triggerAction(action)
            }
            
            actionButtons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        container.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupGestures() {
        guard let targetView = targetView else { return }
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture?.delegate = self
        targetView.addGestureRecognizer(panGesture!)
        
        initialCenter = targetView.center
    }
    
    // MARK: - Gesture Handling
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let targetView = targetView else { return }
        
        let translation = gesture.translation(in: targetView.superview)
        let velocity = gesture.velocity(in: targetView.superview)
        
        switch gesture.state {
        case .began:
            initialCenter = targetView.center
            
        case .changed:
            // Only allow left swipe
            let newX = max(initialCenter.x + translation.x, initialCenter.x - 160)
            targetView.center = CGPoint(x: newX, y: initialCenter.y)
            
            // Show/hide actions based on swipe distance
            let swipeDistance = initialCenter.x - targetView.center.x
            updateActionsVisibility(swipeDistance: swipeDistance)
            
        case .ended, .cancelled:
            let swipeDistance = initialCenter.x - targetView.center.x
            let shouldShowActions = swipeDistance > 40 || velocity.x < -500
            
            animateToFinalPosition(showActions: shouldShowActions)
            
        default:
            break
        }
    }
    
    private func updateActionsVisibility(swipeDistance: CGFloat) {
        guard let container = actionsContainer else { return }
        
        let progress = min(swipeDistance / 80, 1.0)
        
        if swipeDistance > 10 && container.isHidden {
            container.isHidden = false
            container.morphGlass(to: .expanding, config: .subtle)
        }
        
        container.alpha = progress
        
        // Scale action buttons based on progress
        actionButtons.enumerated().forEach { index, button in
            let buttonProgress = max(0, min(1, (progress - Float(index) * 0.2) * 1.5))
            button.transform = CGAffineTransform(scaleX: CGFloat(buttonProgress), y: CGFloat(buttonProgress))
        }
    }
    
    private func animateToFinalPosition(showActions: Bool) {
        guard let targetView = targetView, let container = actionsContainer else { return }
        
        let targetX = showActions ? initialCenter.x - 160 : initialCenter.x
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            targetView.center = CGPoint(x: targetX, y: self.initialCenter.y)
            
            if showActions {
                container.alpha = 1.0
                self.actionButtons.forEach { button in
                    button.transform = .identity
                }
            } else {
                container.alpha = 0.0
                self.actionButtons.forEach { button in
                    button.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                }
            }
        } completion: { _ in
            if !showActions {
                container.isHidden = true
                container.morphGlass(to: .idle, config: .subtle)
            }
            self.isActionsVisible = showActions
        }
    }
    
    private func triggerAction(_ action: ActionType) {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate action
        if let button = actionButtons.first(where: { $0.actionType == action }) {
            button.morphButton(to: .pressed) {
                button.morphButton(to: .idle)
            }
        }
        
        // Hide actions and trigger callback
        hideActions {
            self.onActionTriggered?(action)
        }
    }
    
    func hideActions(completion: (() -> Void)? = nil) {
        guard let targetView = targetView, let container = actionsContainer else {
            completion?()
            return
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            targetView.center = self.initialCenter
            container.alpha = 0.0
        } completion: { _ in
            container.isHidden = true
            container.morphGlass(to: .idle, config: .subtle)
            self.isActionsVisible = false
            completion?()
        }
    }
}

// MARK: - Swipe Action Button

class LGSwipeActionButton: LGBaseView {
    
    // MARK: - Properties
    let actionType: LGSwipeActionsController.ActionType
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
    var onTap: (() -> Void)?
    
    // MARK: - Initialization
    
    init(action: LGSwipeActionsController.ActionType) {
        self.actionType = action
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        glassIntensity = 0.6
        cornerRadius = 0
        backgroundColor = actionType.color.withAlphaComponent(0.8)
        
        iconImageView.image = actionType.icon
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        
        titleLabel.text = actionType.title
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        
        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-8)
            make.size.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconImageView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(4)
        }
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    @objc private func handleTap() {
        onTap?()
    }
    
    func morphButton(to state: LGMorphState, completion: (() -> Void)? = nil) {
        morphGlass(to: state, config: .default, completion: completion)
    }
}

// MARK: - Drag and Drop Controller

class LGDragDropController: NSObject {
    
    // MARK: - Properties
    private weak var sourceView: UIView?
    private var dragPreviewView: LGDragPreviewView?
    private var dropZones: [LGDropZone] = []
    private var isDragging = false
    
    var onDragStarted: ((UIView) -> Void)?
    var onDragEnded: ((UIView, LGDropZone?) -> Void)?
    var onDropCompleted: ((UIView, LGDropZone) -> Bool)?
    
    // MARK: - Initialization
    
    init(sourceView: UIView) {
        self.sourceView = sourceView
        super.init()
        setupDragGesture()
    }
    
    // MARK: - Setup
    
    private func setupDragGesture() {
        guard let sourceView = sourceView else { return }
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        sourceView.addGestureRecognizer(longPress)
    }
    
    func addDropZone(_ dropZone: LGDropZone) {
        dropZones.append(dropZone)
    }
    
    // MARK: - Drag Handling
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let sourceView = sourceView else { return }
        
        switch gesture.state {
        case .began:
            startDrag(at: gesture.location(in: sourceView.superview))
            
        case .changed:
            updateDrag(to: gesture.location(in: sourceView.superview))
            
        case .ended, .cancelled:
            endDrag(at: gesture.location(in: sourceView.superview))
            
        default:
            break
        }
    }
    
    private func startDrag(at point: CGPoint) {
        guard let sourceView = sourceView else { return }
        
        isDragging = true
        
        // Create drag preview
        dragPreviewView = LGDragPreviewView(sourceView: sourceView)
        if let preview = dragPreviewView, let superview = sourceView.superview {
            superview.addSubview(preview)
            preview.center = point
        }
        
        // Hide original view
        sourceView.alpha = 0.3
        
        // Activate drop zones
        dropZones.forEach { $0.activate() }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        onDragStarted?(sourceView)
    }
    
    private func updateDrag(to point: CGPoint) {
        guard let preview = dragPreviewView else { return }
        
        // Update preview position
        UIView.animate(withDuration: 0.1) {
            preview.center = point
        }
        
        // Check drop zones
        let activeDropZone = dropZones.first { dropZone in
            return dropZone.frame.contains(point)
        }
        
        // Update drop zone states
        dropZones.forEach { dropZone in
            if dropZone == activeDropZone {
                dropZone.highlight()
            } else {
                dropZone.unhighlight()
            }
        }
    }
    
    private func endDrag(at point: CGPoint) {
        guard let sourceView = sourceView, let preview = dragPreviewView else { return }
        
        isDragging = false
        
        // Find drop zone
        let targetDropZone = dropZones.first { dropZone in
            return dropZone.frame.contains(point)
        }
        
        // Animate preview back or to drop zone
        if let dropZone = targetDropZone {
            // Animate to drop zone
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                preview.center = dropZone.center
                preview.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                preview.alpha = 0.0
            } completion: { _ in
                preview.removeFromSuperview()
                self.dragPreviewView = nil
                
                // Handle drop
                let success = self.onDropCompleted?(sourceView, dropZone) ?? false
                if success {
                    dropZone.acceptDrop()
                    sourceView.alpha = 1.0
                } else {
                    dropZone.rejectDrop()
                    self.animateSourceViewBack()
                }
            }
        } else {
            // Animate back to original position
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                preview.center = sourceView.center
                preview.alpha = 0.0
            } completion: { _ in
                preview.removeFromSuperview()
                self.dragPreviewView = nil
                self.animateSourceViewBack()
            }
        }
        
        // Deactivate drop zones
        dropZones.forEach { $0.deactivate() }
        
        onDragEnded?(sourceView, targetDropZone)
    }
    
    private func animateSourceViewBack() {
        guard let sourceView = sourceView else { return }
        
        UIView.animate(withDuration: 0.2) {
            sourceView.alpha = 1.0
        }
    }
}

// MARK: - Drag Preview View

class LGDragPreviewView: LGBaseView {
    
    init(sourceView: UIView) {
        super.init(frame: sourceView.bounds)
        setupPreview(from: sourceView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupPreview(from sourceView: UIView) {
        glassIntensity = 0.8
        cornerRadius = 12
        enableGlassBorder = true
        
        // Create snapshot
        if let snapshot = sourceView.snapshotView(afterScreenUpdates: false) {
            addSubview(snapshot)
            snapshot.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 16
        layer.shadowOpacity = 0.3
        
        // Initial animation
        transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        morphGlass(to: .expanding, config: .default)
    }
}

// MARK: - Drop Zone

class LGDropZone: LGBaseView {
    
    // MARK: - Properties
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private var isActive = false
    
    // MARK: - Initialization
    
    init(title: String, icon: UIImage?) {
        super.init(frame: .zero)
        setupUI(title: title, icon: icon)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI(title: String, icon: UIImage?) {
        glassIntensity = 0.3
        cornerRadius = 16
        enableGlassBorder = true
        alpha = 0.0
        
        iconImageView.image = icon
        iconImageView.tintColor = LGThemeManager.shared.primaryGlassColor
        iconImageView.contentMode = .scaleAspectFit
        
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .semibold)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        titleLabel.textAlignment = .center
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        
        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-12)
            make.size.equalTo(32)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconImageView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(8)
        }
    }
    
    // MARK: - State Management
    
    func activate() {
        isActive = true
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1.0
        }
        morphGlass(to: .shimmerPulse, config: .subtle)
    }
    
    func deactivate() {
        isActive = false
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0.0
        }
        morphGlass(to: .idle, config: .subtle)
    }
    
    func highlight() {
        guard isActive else { return }
        morphGlass(to: .expanding, config: .default)
        backgroundColor = LGThemeManager.shared.primaryGlassColor.withAlphaComponent(0.2)
    }
    
    func unhighlight() {
        guard isActive else { return }
        morphGlass(to: .shimmerPulse, config: .subtle)
        backgroundColor = .clear
    }
    
    func acceptDrop() {
        morphGlass(to: .pressed, config: .default) {
            self.morphGlass(to: .idle, config: .subtle)
        }
        
        // Success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func rejectDrop() {
        morphGlass(to: .liquidWave, config: .default) {
            self.morphGlass(to: .shimmerPulse, config: .subtle)
        }
        
        // Error haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension LGSwipeActionsController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = panGesture.velocity(in: gestureRecognizer.view)
            return abs(velocity.x) > abs(velocity.y)
        }
        return true
    }
}
