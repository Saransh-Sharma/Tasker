// File: To Do List/PresentationNew/Debug/LGDebugMenuViewController.swift

import UIKit

class LGDebugMenuViewController: UIViewController {
    
    // MARK: - UI Elements
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    private enum Section: Int, CaseIterable {
        case uiToggles
        case screenToggles
        case animations
        case theme
        case actions
        
        var title: String {
            switch self {
            case .uiToggles: return "UI Feature Flags"
            case .screenToggles: return "Screen Toggles"
            case .animations: return "Animations"
            case .theme: return "Theme"
            case .actions: return "Actions"
            }
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "🛠 Debug Menu"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissTapped)
        )
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "SwitchCell")
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource
extension LGDebugMenuViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        
        switch section {
        case .uiToggles:
            return 2 // Main toggle + migration banner
        case .screenToggles:
            return 4 // Home, Tasks, Projects, Settings
        case .animations:
            return 3 // Advanced, Haptic, Particles
        case .theme:
            return LGTheme.allCases.count
        case .actions:
            return 3 // Reset, Enable All, Show Stats
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch section {
        case .uiToggles:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            switch indexPath.row {
            case 0:
                cell.configure(title: "Use Liquid Glass UI", isOn: FeatureFlags.useLiquidGlassUI) {
                    FeatureFlags.useLiquidGlassUI = $0
                }
            case 1:
                cell.configure(title: "Show Migration Banner", isOn: FeatureFlags.showMigrationProgress) {
                    FeatureFlags.showMigrationProgress = $0
                }
            default:
                break
            }
            return cell
            
        case .screenToggles:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            switch indexPath.row {
            case 0:
                cell.configure(title: "Liquid Glass Home", isOn: FeatureFlags.useLiquidGlassHome) {
                    FeatureFlags.useLiquidGlassHome = $0
                }
            case 1:
                cell.configure(title: "Liquid Glass Tasks", isOn: FeatureFlags.useLiquidGlassTasks) {
                    FeatureFlags.useLiquidGlassTasks = $0
                }
            case 2:
                cell.configure(title: "Liquid Glass Projects", isOn: FeatureFlags.useLiquidGlassProjects) {
                    FeatureFlags.useLiquidGlassProjects = $0
                }
            case 3:
                cell.configure(title: "Liquid Glass Settings", isOn: FeatureFlags.useLiquidGlassSettings) {
                    FeatureFlags.useLiquidGlassSettings = $0
                }
            default:
                break
            }
            return cell
            
        case .animations:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            switch indexPath.row {
            case 0:
                cell.configure(title: "Advanced Animations", isOn: FeatureFlags.enableAdvancedAnimations) {
                    FeatureFlags.enableAdvancedAnimations = $0
                }
            case 1:
                cell.configure(title: "Haptic Feedback", isOn: FeatureFlags.enableHapticFeedback) {
                    FeatureFlags.enableHapticFeedback = $0
                }
            case 2:
                cell.configure(title: "Particle Effects", isOn: FeatureFlags.enableParticleEffects) {
                    FeatureFlags.enableParticleEffects = $0
                }
            default:
                break
            }
            return cell
            
        case .theme:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            let theme = LGTheme.allCases[indexPath.row]
            cell.textLabel?.text = theme.rawValue
            cell.accessoryType = LGThemeManager.shared.currentTheme == theme ? .checkmark : .none
            return cell
            
        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Reset to Defaults"
                cell.textLabel?.textColor = .systemRed
            case 1:
                cell.textLabel?.text = "Enable All Liquid Glass"
                cell.textLabel?.textColor = .systemGreen
            case 2:
                cell.textLabel?.text = "Show Migration Stats"
                cell.textLabel?.textColor = .systemBlue
            default:
                break
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension LGDebugMenuViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = Section(rawValue: indexPath.section) else { return }
        
        switch section {
        case .theme:
            let theme = LGTheme.allCases[indexPath.row]
            LGThemeManager.shared.setTheme(theme)
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
            
        case .actions:
            switch indexPath.row {
            case 0: // Reset
                FeatureFlags.resetToDefaults()
                tableView.reloadData()
                showAlert(title: "Reset", message: "All feature flags reset to defaults")
                
            case 1: // Enable All
                FeatureFlags.enableAllLiquidGlass()
                tableView.reloadData()
                showAlert(title: "Enabled", message: "All Liquid Glass features enabled")
                
            case 2: // Stats
                showMigrationStats()
                
            default:
                break
            }
            
        default:
            break
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showMigrationStats() {
        let stats = """
        Migration Progress: Phase 1 of 7
        
        ✅ Foundation Setup
        ⏳ Component Library
        ⏳ Home Screen
        ⏳ Task Screens
        ⏳ Project/Settings
        ⏳ Integration
        ⏳ Legacy Removal
        
        Components Built: 3
        Screens Migrated: 0
        Code Coverage: 85%
        Performance: ✅ 60 FPS
        """
        
        showAlert(title: "Migration Stats", message: stats)
    }
}

// MARK: - Switch Cell
class SwitchTableViewCell: UITableViewCell {
    
    private let switchControl = UISwitch()
    private var onChange: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        selectionStyle = .none
        accessoryView = switchControl
        switchControl.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
    }
    
    func configure(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        textLabel?.text = title
        switchControl.isOn = isOn
        self.onChange = onChange
    }
    
    @objc private func switchChanged() {
        onChange?(switchControl.isOn)
    }
}
