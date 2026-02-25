# macOS-Like Desktop Environment Makefile

CXX = clang++
OBJCXX = clang++

# Frameworks
FRAMEWORKS = -framework Cocoa -framework WebKit -framework IOKit -framework AVFoundation -framework UniformTypeIdentifiers -framework CoreWLAN -framework QuartzCore -framework Metal -framework SystemConfiguration -framework Security

# Compiler flags
CXXFLAGS = -std=c++17 -Wall -Wextra -O2
OBJCXXFLAGS = -std=c++17 -Wall -Wextra -O2 -fobjc-arc

# Source directories
SRC_DIR = src
VIEWS_DIR = $(SRC_DIR)/views
WINDOWS_DIR = $(SRC_DIR)/windows
HELPERS_DIR = $(SRC_DIR)/helpers
SERVICES_DIR = $(SRC_DIR)/services

# Output
BUILD_DIR = build
APP_NAME = macOSDesktop
EXECUTABLE = $(BUILD_DIR)/$(APP_NAME)

# Source files
MAIN_SRC = $(SRC_DIR)/main.mm
APP_DELEGATE_SRC = $(SRC_DIR)/AppDelegate.mm

VIEW_SOURCES = \
	$(VIEWS_DIR)/MenuBarView.mm \
	$(VIEWS_DIR)/DockView.mm \
	$(VIEWS_DIR)/DesktopView.mm

WINDOW_SOURCES = \
	$(WINDOWS_DIR)/AboutThisMacWindow.mm \
	$(WINDOWS_DIR)/FinderWindow.mm \
	$(WINDOWS_DIR)/SafariWindow.mm \
	$(WINDOWS_DIR)/MessagesWindow.mm \
	$(WINDOWS_DIR)/TerminalWindow.mm \
	$(WINDOWS_DIR)/NotesWindow.mm \
	$(WINDOWS_DIR)/CalendarWindow.mm \
	$(WINDOWS_DIR)/SettingsWindow.mm \
	$(WINDOWS_DIR)/MailWindow.mm \
	$(WINDOWS_DIR)/PhotosWindow.mm \
	$(WINDOWS_DIR)/MusicWindow.mm \
	$(WINDOWS_DIR)/WiFiWindow.mm \
	$(WINDOWS_DIR)/SetupWizardWindow.mm \
	$(WINDOWS_DIR)/ForceQuitWindow.mm \
	$(WINDOWS_DIR)/SecurityWindow.mm \
	$(WINDOWS_DIR)/AntivirusWindow.mm \
	$(WINDOWS_DIR)/SMSConfigWindow.mm \
	$(WINDOWS_DIR)/SoftwareUpdateWindow.mm \
	$(WINDOWS_DIR)/ActivityMonitorWindow.mm \
	$(WINDOWS_DIR)/DiskUtilityWindow.mm \
	$(WINDOWS_DIR)/ConsoleWindow.mm \
	$(WINDOWS_DIR)/NetworkUtilityWindow.mm \
	$(WINDOWS_DIR)/AutomatorWindow.mm \
	$(WINDOWS_DIR)/AccessibilityWindow.mm

HELPER_SOURCES = \
	$(HELPERS_DIR)/SystemInfoHelper.mm \
	$(HELPERS_DIR)/GlassmorphismHelper.mm

SERVICE_SOURCES = \
	$(SERVICES_DIR)/NativeSMSEngine.mm \
	$(SERVICES_DIR)/NetworkEngine.mm \
	$(SERVICES_DIR)/FileSystemManager_Base.mm \
	$(SERVICES_DIR)/FileSystemManager_Core.mm \
	$(SERVICES_DIR)/FileSystemManager_Transfer.mm \
	$(SERVICES_DIR)/FileSystemManager_Execution.mm \
	$(SERVICES_DIR)/FileSystemManager_Preview.mm \
	$(SERVICES_DIR)/FileSystemManager_Metadata.mm \
	$(SERVICES_DIR)/FileSystemManager_Types.mm \
	$(SERVICES_DIR)/FileSystemManager_Search.mm \
	$(SERVICES_DIR)/FileSystemManager_Archive.mm \
	$(SERVICES_DIR)/FileSystemManager_DiskImage.mm \
	$(SERVICES_DIR)/FileSystemManager_Package.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_Core.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_BuiltIn.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_FileCommands.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_TextCommands.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_ProcessCommands.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_NetworkCommands.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_SystemCommands.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_UserCommands.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_ArchiveCommands.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_PackageCommands.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_DevCommands.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_MiscCommands.mm \
	$(SERVICES_DIR)/CrossPlatformCommandEngine_Utilities.mm \
	$(SERVICES_DIR)/UpdateManager.mm \
	$(SERVICES_DIR)/DriverManager.mm \
	$(SERVICES_DIR)/AdvancedKernel_Memory.mm \
	$(SERVICES_DIR)/AdvancedKernel_Scheduler.mm \
	$(SERVICES_DIR)/AdvancedKernel_Core.mm \
	$(SERVICES_DIR)/CPUArchitectureManager.mm \
	$(SERVICES_DIR)/GPUArchitectureManager.mm \
	$(SERVICES_DIR)/UniversalFileTypeEngine.mm

ALL_SOURCES = $(MAIN_SRC) $(APP_DELEGATE_SRC) $(VIEW_SOURCES) $(WINDOW_SOURCES) $(HELPER_SOURCES) $(SERVICE_SOURCES)

# Object files
OBJECTS = $(patsubst $(SRC_DIR)/%.mm,$(BUILD_DIR)/%.o,$(ALL_SOURCES))

# Default target
all: $(EXECUTABLE)

# Create build directories
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/views
	mkdir -p $(BUILD_DIR)/windows
	mkdir -p $(BUILD_DIR)/helpers
	mkdir -p $(BUILD_DIR)/services

# Compile Objective-C++ files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.mm | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(OBJCXX) $(OBJCXXFLAGS) -I$(SRC_DIR) -c $< -o $@

# Link executable
$(EXECUTABLE): $(OBJECTS)
	$(OBJCXX) $(OBJCXXFLAGS) $(FRAMEWORKS) $^ -o $@

# Run the application
run: $(EXECUTABLE)
	./$(EXECUTABLE)

# Clean build files
clean:
	rm -rf $(BUILD_DIR)

# Rebuild
rebuild: clean all

# Debug build
debug: OBJCXXFLAGS += -g -DDEBUG
debug: all

# Show help
help:
	@echo "Available targets:"
	@echo "  all     - Build the application (default)"
	@echo "  run     - Build and run the application"
	@echo "  clean   - Remove build files"
	@echo "  rebuild - Clean and build"
	@echo "  debug   - Build with debug symbols"
	@echo "  help    - Show this help message"

.PHONY: all run clean rebuild debug help
