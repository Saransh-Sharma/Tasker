// Device Adaptive Components
// Provides iPad and iPhone optimized layouts and interactions for Liquid Glass UI

import UIKit

// MARK: - Device Detection
struct LGDevice {
    
    static var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    static var isCompact: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return false }
        return window.traitCollection.horizontalSizeClass == .compact
    }
    
    static var isRegular: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return false }
        return window.traitCollection.horizontalSizeClass == .regular
    }
    
    static var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    static var safeAreaInsets: UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return .zero }
        return window.safeAreaInsets
    }
}

// MARK: - Adaptive Layout Constants
struct LGLayoutConstants {
    
    // Margins
    static var horizontalMargin: CGFloat {
        if LGDevice.isIPad {
            return LGDevice.isRegular ? 40 : 24
        } else {
            return 16
        }
    }
    
    static var verticalMargin: CGFloat {
        return LGDevice.isIPad ? 24 : 16
    }
    
    // Card dimensions
    static var cardCornerRadius: CGFloat {
        return LGDevice.isIPad ? 24 : 20
    }
    
    static var cardMinHeight: CGFloat {
        return LGDevice.isIPad ? 120 : 100
    }
    
    // Font sizes
    static var titleFontSize: CGFloat {
        if LGDevice.isIPad {
            return LGDevice.isRegular ? 28 : 24
        } else {
            return 20
        }
    }
    
    static var bodyFontSize: CGFloat {
        if LGDevice.isIPad {
            return LGDevice.isRegular ? 18 : 16
        } else {
            return 14
        }
    }
    
    static var captionFontSize: CGFloat {
        if LGDevice.isIPad {
            return LGDevice.isRegular ? 16 : 14
        } else {
            return 12
        }
    }
    
    // Grid layout
    static var numberOfColumns: Int {
        if LGDevice.isIPad {
            return LGDevice.isRegular ? 3 : 2
        } else {
            return 1
        }
    }
    
    static var itemSpacing: CGFloat {
        return LGDevice.isIPad ? 20 : 12
    }
    
    // Navigation
    static var navigationBarHeight: CGFloat {
        return LGDevice.isIPad ? 64 : 56
    }
    
    // Floating Action Button
    static var fabSize: CGFloat {
        return LGDevice.isIPad ? 64 : 56
    }
    
    static var fabBottomMargin: CGFloat {
        return LGDevice.isIPad ? 40 : 24
    }
}

// MARK: - Adaptive Glass View
class LGAdaptiveView: LGBaseView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAdaptiveProperties()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAdaptiveProperties()
    }
    
    private func setupAdaptiveProperties() {
        // Adjust corner radius for device
        cornerRadius = LGLayoutConstants.cardCornerRadius
        
        // Adjust glass intensity for larger screens
        if LGDevice.isIPad {
            glassIntensity = 0.9 // Slightly more intense on iPad
        }
        
        // Listen for trait collection changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleOrientationChange() {
        setupAdaptiveProperties()
        setNeedsLayout()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Adaptive Stack View
class LGAdaptiveStackView: UIStackView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAdaptiveLayout()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupAdaptiveLayout()
    }
    
    private func setupAdaptiveLayout() {
        // Adjust layout based on device
        if LGDevice.isIPad && LGDevice.isRegular {
            axis = .horizontal
            distribution = .fillEqually
            spacing = LGLayoutConstants.itemSpacing
        } else {
            axis = .vertical
            distribution = .fill
            spacing = LGLayoutConstants.itemSpacing / 2
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setupAdaptiveLayout()
    }
}

// MARK: - Adaptive Collection View Layout
class LGAdaptiveFlowLayout: UICollectionViewFlowLayout {
    
    override func prepare() {
        super.prepare()
        
        guard let collectionView = collectionView else { return }
        
        let availableWidth = collectionView.bounds.width - sectionInset.left - sectionInset.right
        let numberOfColumns = CGFloat(LGLayoutConstants.numberOfColumns)
        let itemSpacing = LGLayoutConstants.itemSpacing
        
        let itemWidth = (availableWidth - (itemSpacing * (numberOfColumns - 1))) / numberOfColumns
        let itemHeight = max(LGLayoutConstants.cardMinHeight, itemWidth * 0.7)
        
        itemSize = CGSize(width: itemWidth, height: itemHeight)
        minimumInteritemSpacing = itemSpacing
        minimumLineSpacing = itemSpacing
        
        // Adjust section insets for iPad
        let horizontalInset = LGLayoutConstants.horizontalMargin
        let verticalInset = LGLayoutConstants.verticalMargin
        sectionInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
    }
}

// MARK: - Adaptive Navigation Controller
class LGAdaptiveNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAdaptiveNavigation()
    }
    
    private func setupAdaptiveNavigation() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = LGThemeManager.shared.primaryGlassColor
        
        // Adjust title font for device
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: LGLayoutConstants.titleFontSize, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        
        // Enable large titles on iPad
        if LGDevice.isIPad {
            navigationBar.prefersLargeTitles = true
            appearance.largeTitleTextAttributes = [
                .font: UIFont.systemFont(ofSize: LGLayoutConstants.titleFontSize + 8, weight: .bold),
                .foregroundColor: UIColor.label
            ]
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setupAdaptiveNavigation()
    }
}

// MARK: - Adaptive Modal Presentation
extension UIViewController {
    
    func presentAdaptively(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        if LGDevice.isIPad {
            // Use popover or form sheet on iPad
            viewController.modalPresentationStyle = .formSheet
            if let popover = viewController.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        } else {
            // Use full screen on iPhone
            viewController.modalPresentationStyle = .fullScreen
        }
        
        present(viewController, animated: animated, completion: completion)
    }
}

// MARK: - Adaptive Gesture Recognizers
class LGAdaptiveGestureManager {
    
    static func addSwipeGestures(to view: UIView, target: Any, leftAction: Selector?, rightAction: Selector?) {
        // More generous swipe gestures on iPad
        let minimumDistance: CGFloat = LGDevice.isIPad ? 100 : 50
        
        if let leftAction = leftAction {
            let leftSwipe = UISwipeGestureRecognizer(target: target, action: leftAction)
            leftSwipe.direction = .left
            view.addGestureRecognizer(leftSwipe)
        }
        
        if let rightAction = rightAction {
            let rightSwipe = UISwipeGestureRecognizer(target: target, action: rightAction)
            rightSwipe.direction = .right
            view.addGestureRecognizer(rightSwipe)
        }
    }
    
    static func addLongPressGesture(to view: UIView, target: Any, action: Selector) {
        let longPress = UILongPressGestureRecognizer(target: target, action: action)
        // Shorter press duration on iPad for better responsiveness
        longPress.minimumPressDuration = LGDevice.isIPad ? 0.3 : 0.5
        view.addGestureRecognizer(longPress)
    }
}

// MARK: - Adaptive Animation Durations
struct LGAnimationDurations {
    
    static var short: TimeInterval {
        return LGDevice.isIPad ? 0.2 : 0.25
    }
    
    static var medium: TimeInterval {
        return LGDevice.isIPad ? 0.3 : 0.4
    }
    
    static var long: TimeInterval {
        return LGDevice.isIPad ? 0.5 : 0.6
    }
    
    static var spring: (damping: CGFloat, velocity: CGFloat) {
        if LGDevice.isIPad {
            return (damping: 0.8, velocity: 0.6)
        } else {
            return (damping: 0.7, velocity: 0.5)
        }
    }
}
