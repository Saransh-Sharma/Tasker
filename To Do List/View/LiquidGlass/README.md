# Liquid Glass UI Components

## Overview

This directory contains the iOS 16+ Liquid Glass UI component library for the Tasker app. These components provide beautiful glass morphism effects with backdrop blur, gradients, and smooth animations.

## Components

### LGBaseView
**Base class for all Liquid Glass components**

```swift
let glassView = LGBaseView()
glassView.cornerRadius = 16
glassView.glassOpacity = 0.8
glassView.glassBlurStyle = .systemUltraThinMaterial
glassView.animateGlassAppearance()
```

**Properties:**
- `glassBlurStyle`: Blur effect style (default: `.systemUltraThinMaterial`)
- `glassOpacity`: Overall opacity (default: `0.8`)
- `cornerRadius`: Corner radius (default: `16`)
- `borderWidth`: Border width (default: `0.5`)
- `borderColor`: Border color (default: white @ 20% opacity)

**Methods:**
- `animateGlassAppearance(duration:)`: Animate view appearance with spring animation

---

### LGSearchBar
**Glass morphism search bar with animations**

```swift
let searchBar = LGSearchBar()
searchBar.delegate = self
searchBar.text = "Search query"
```

**Delegate Methods:**
```swift
func searchBar(_ searchBar: LGSearchBar, textDidChange text: String)
func searchBarDidBeginEditing(_ searchBar: LGSearchBar)
func searchBarDidEndEditing(_ searchBar: LGSearchBar)
func searchBarSearchButtonTapped(_ searchBar: LGSearchBar)
func searchBarCancelButtonTapped(_ searchBar: LGSearchBar)
```

**Features:**
- Auto-showing cancel button on focus
- Clear button when text is entered
- Animated border on focus/unfocus
- Magnifying glass icon
- White text with semi-transparent placeholder

---

### LGTaskCard
**Task display card with glass effects**

```swift
let taskCard = LGTaskCard()
taskCard.task = myTask // NTask object
taskCard.onTap = { task in
    print("Tapped task: \(task.name)")
}
```

**Features:**
- Interactive checkbox for completion toggle
- Priority indicator with color coding
- Project label display
- Due date formatting
- Strike-through for completed tasks
- Tap animation feedback
- Automatic Core Data saving

**Priority Colors:**
- Priority 1 (Highest): Red
- Priority 2 (High): Orange
- Priority 3 (Medium): Yellow
- Priority 4 (Low): Green

---

## Usage Example

### Creating a Custom Glass View

```swift
class MyCustomView: LGBaseView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Customize glass effect
        cornerRadius = 20
        glassOpacity = 0.9
        
        // Add your subviews here
        let label = UILabel()
        label.text = "Hello, Glass!"
        label.textColor = .white
        addSubview(label)
        
        // Animate appearance
        animateGlassAppearance()
    }
}
```

### Using Search Bar

```swift
class MyViewController: UIViewController, LGSearchBarDelegate {
    let searchBar = LGSearchBar()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        view.addSubview(searchBar)
        
        // Setup constraints...
    }
    
    func searchBar(_ searchBar: LGSearchBar, textDidChange text: String) {
        print("Search text: \(text)")
        // Perform search...
    }
}
```

### Displaying Task Cards

```swift
let tasks: [NTask] = fetchTasks()

for task in tasks {
    let card = LGTaskCard()
    card.task = task
    card.onTap = { [weak self] task in
        self?.showTaskDetail(task)
    }
    stackView.addArrangedSubview(card)
}
```

## Design Guidelines

### Colors
- **Text**: White with varying opacity (100%, 70%, 50%)
- **Icons**: White @ 60-80% opacity
- **Borders**: White @ 20% opacity
- **Background**: Blur + gradient overlay

### Animations
- **Duration**: 0.2-0.4 seconds
- **Spring Damping**: 0.8
- **Spring Velocity**: 0.5
- **Easing**: `.easeOut` or spring-based

### Spacing
- **Padding**: 12-16pt
- **Corner Radius**: 12-16pt
- **Icon Size**: 20-24pt
- **Border Width**: 0.5-1.0pt

## Requirements

- iOS 16.0+
- Swift 5.0+
- UIKit framework
- CoreData (for LGTaskCard)

## Architecture

All components follow these principles:
- **Inheritance**: Extend `LGBaseView` for glass effects
- **Delegation**: Use delegates for event handling
- **Closures**: Use closures for simple callbacks
- **Animations**: Use spring-based animations for natural feel
- **Accessibility**: Support VoiceOver and Dynamic Type

## Notes

- All components are designed for dark-themed interfaces
- Glass effects work best on colored backgrounds
- Animations are optimized for 60 FPS performance
- Components are fully compatible with Auto Layout
- Memory management uses weak references in closures

## Support

For issues or questions, refer to the main implementation documentation:
`/LIQUID_GLASS_SEARCH_IMPLEMENTATION.md`
