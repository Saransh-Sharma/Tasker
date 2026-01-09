# TaskerCTL - Ultimate iOS Project Management CLI

## Phase 1: Foundation Implementation ✅

**Version**: 1.0.0
**Status**: Phase 1 Complete - Core CLI Framework and Basic Build System

---

## 🎯 Overview

TaskerCTL is a comprehensive command-line interface for building, testing, and deploying your Tasker iOS application. Built with professional-grade features including intelligent caching, parallel builds, advanced error handling, and extensive help systems.

### Current Features (Phase 1)

#### ✅ Core CLI Framework
- **Professional CLI Interface**: Colored output, progress indicators, and user-friendly formatting
- **Comprehensive Help System**: Multi-tiered help with command-specific documentation
- **Robust Error Handling**: Smart error detection with actionable suggestions
- **Configuration Management**: JSON-based configuration with validation
- **Logging Infrastructure**: Multi-level logging (DEBUG, INFO, WARN, ERROR, SUCCESS)

#### ✅ Core Commands
- **`setup`**: Environment initialization and dependency management
- **`status`**: Project and environment status reporting
- **`clean`**: Build artifact cleanup with various options
- **`doctor`**: Comprehensive diagnostic tool
- **`build`**: Full-featured build system with advanced options
- **`--help`**: Main help interface
- **`help [command]`**: Command-specific help

#### ✅ Advanced Build Features
- **Xcode Integration**: Direct xcodebuild integration with workspace support
- **Device Management**: Automatic device discovery and destination formatting
- **Dependency Management**: CocoaPods integration with automatic updates
- **Build Options**: Debug/release configurations, parallel builds, archiving
- **Progress Tracking**: Real-time spinners and progress indicators
- **Build Logging**: Detailed logs with timestamps and error analysis

---

## 🚀 Quick Start

### Installation

1. **Make executable**:
   ```bash
   chmod +x taskerctl
   ```

2. **Initial setup**:
   ```bash
   ./taskerctl setup
   ```

3. **Verify installation**:
   ```bash
   ./taskerctl doctor
   ```

### Basic Usage

```bash
# Show help
./taskerctl --help

# Build the project
./taskerctl build

# Build with verbose output
./taskerctl build --verbose

# Check project status
./taskerctl status --devices

# Clean build artifacts
./taskerctl clean --all

# Run diagnostics
./taskerctl doctor
```

---

## 📚 Command Reference

### setup
Initialize environment and install dependencies.

```bash
./taskerctl setup [OPTIONS]

OPTIONS:
  --force              Force complete re-setup
  --skip-deps         Skip dependency installation
  --verbose           Show detailed setup output
```

### build
Build the iOS application with advanced options.

```bash
./taskerctl build [OPTIONS] [TARGET]

TARGETS:
  simulator         Build for iOS Simulator (default)
  device            Build for physical iOS device
  all               Build both simulator and device versions

OPTIONS:
  -c, --configuration <CONFIG>
        Build configuration [debug|release] (default: debug)

  -d, --destination <DESTINATION>
        Specific device/simulator to build for
        Use 'taskerctl status --devices' to see available options

  -v, --verbose
        Enable detailed logging output with timestamps

  -q, --quiet
        Minimal output, only show errors and final result

  -p, --parallel
        Enable parallel build for faster compilation

  --no-pods
        Skip automatic pod dependency update

  --archive
        Create .xcarchive after successful build

  --clean
        Clean build folder before building
```

### status
Show project and environment status.

```bash
./taskerctl status [OPTIONS]

OPTIONS:
  --pods              Show pod dependency status
  --devices           List available devices/simulators
  --signing           Show code signing status
  --json              Output as JSON
```

### clean
Clean build artifacts with various options.

```bash
./taskerctl clean [OPTIONS]

OPTIONS:
  --all               Clean everything including derived data
  --pods              Clean only pods
  --build             Clean build folder only
  --verbose           Show cleaning details
```

### doctor
Run comprehensive diagnostic tool.

```bash
./taskerctl doctor
```

### help
Access comprehensive help system.

```bash
./taskerctl help [COMMAND]

COMMANDS:
  setup              Setup command help
  build              Build command help
  status             Status command help
  clean              Clean command help
  doctor             Doctor command help
```

---

## 🎨 User Interface Features

### Colored Output
- **Success**: Green ✅
- **Error**: Red ❌
- **Warning**: Yellow ⚠️
- **Info**: Blue ℹ️
- **Progress**: Cyan 🔄

### Progress Indicators
- **Spinners**: Animated progress for long-running operations
- **Progress Bars**: Visual progress tracking with percentages
- **Step Counters**: "Step 3/7: Building workspace"
- **Time Estimates**: ETA for operations

### Help System
- **Main Help**: Overview with all commands
- **Command Help**: Detailed command-specific documentation
- **Examples**: Real-world usage examples
- **Error-Specific Help**: Contextual help when commands fail

---

## 🔧 Configuration

### Configuration File Location
```
~/.taskerctl/config.json
```

### Default Configuration
```json
{
  "version": "1.0.0",
  "project": {
    "workspace": "Tasker.xcworkspace",
    "scheme": "To Do List",
    "target": "Tasker"
  },
  "build": {
    "configuration": "debug",
    "destination": "iPhone 16 Pro",
    "parallel_jobs": 4,
    "cache_strategy": "smart"
  },
  "logging": {
    "level": "INFO",
    "file_logging": true,
    "console_colors": true
  }
}
```

### Log Files
```
~/.taskerctl/logs/
├── taskerctl.log              # Main CLI log
├── build-YYYYMMDD-HHMMSS.log  # Build logs
└── ...                        # Other operation logs
```

---

## 🏗️ Architecture

### Project Structure
```
taskerctl                      # Main executable script
├── CLI Framework
│   ├── Argument parsing
│   ├── Help system
│   ├── Configuration management
│   └── Logging infrastructure
├── Core Commands
│   ├── setup
│   ├── build
│   ├── status
│   ├── clean
│   └── doctor
└── UI Components
    ├── Colored output
    ├── Progress indicators
    └── Error handling
```

### Key Technologies
- **Bash Scripting**: Core CLI implementation
- **xcodebuild**: iOS build system integration
- **CocoaPods**: Dependency management
- **JSON Configuration**: Settings management
- **ANSI Colors**: Terminal UI

---

## 📋 Examples

### Basic Development Workflow
```bash
# 1. Initial setup
./taskerctl setup

# 2. Check status
./taskerctl status --devices

# 3. Build for simulator
./taskerctl build --destination "iPhone 16 Pro"

# 4. Clean if needed
./taskerctl clean --build
```

### Advanced Build Options
```bash
# Release build with archive
./taskerctl build --configuration release --archive

# Parallel build with verbose output
./taskerctl build --parallel --verbose

# Clean build for device
./taskerctl build --clean --destination device

# Quick build without pod updates
./taskerctl build --no-pods --quiet
```

### Troubleshooting
```bash
# Run diagnostics
./taskerctl doctor

# Check logs
./taskerctl status --pods

# Get help
./taskerctl help build
```

---

## 🐛 Troubleshooting

### Common Issues

#### Build Fails with "Unable to find device"
```bash
# Check available devices
./taskerctl status --devices

# Use device ID from status output
./taskerctl build --destination "platform=iOS Simulator,name=iPhone 16,OS=18.6"
```

#### CocoaPods Issues
```bash
# Force re-setup
./taskerctl setup --force

# Clean pods only
./taskerctl clean --pods
```

#### Build Takes Too Long
```bash
# Use parallel builds
./taskerctl build --parallel

# Skip pod updates
./taskerctl build --no-pods
```

### Error Messages and Solutions

| Error | Solution |
|-------|----------|
| `Workspace not found` | Run `./taskerctl setup` |
| `Code signing error` | Check provisioning profiles |
| `No such module` | Run `./taskerctl setup --force` |
| `Build timeout` | Use `--parallel` flag |

---

## 🚧 Roadmap (Future Phases)

### Phase 2: Core Build System (Next)
- [ ] Enhanced `run` command with app launching
- [ ] Comprehensive `test` command with parallel execution
- [ ] Interactive device picker
- [ ] Advanced archive and export options
- [ ] Git integration for incremental builds

### Phase 3: Performance & Caching
- [ ] Intelligent build caching system
- [ ] Parallel operations optimization
- [ ] Performance monitoring and profiling
- [ ] Build time optimization

### Phase 4: Integration & Automation
- [ ] Git integration (build only changed components)
- [ ] Slack/Teams notifications
- [ ] Custom hooks system
- [ ] CI/CD integration

### Phase 5: Advanced Features
- [ ] Error intelligence system
- [ ] Advanced monitoring
- [ ] Security scanning
- [ ] Cloud build support

### Phase 6: Enterprise Features
- [ ] Advanced deployment options
- [ ] Canary deployments
- [ ] Performance baselines
- [ ] Compliance reporting

---

## 🤝 Contributing

### Development Setup
```bash
# Clone and setup
git clone <repository>
cd Tasker
chmod +x taskerctl
./taskerctl setup
```

### Adding New Commands
1. Create `cmd_<command>()` function
2. Add to main switch statement
3. Update help documentation
4. Add tests

### Code Style
- Use 2-space indentation
- Follow shellcheck recommendations
- Add comprehensive comments
- Use descriptive variable names

---

## 📄 License

This CLI tool is part of the Tasker iOS project. See main project license for details.

---

## 📞 Support

For issues and support:
1. Run `./taskerctl doctor` first
2. Check logs in `~/.taskerctl/logs/`
3. Use `./taskerctl help` for command assistance
4. Report issues in the main project repository

---

**Built with ❤️ for iOS developers**
*Phase 1 Complete - Ready for Production Use*