cmake_minimum_required(VERSION 3.16)

project(xiaou-todo VERSION 2.1.2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Deepin 25 / Dtk6 环境只有 Qt6。原先的 find_package(QT NAMES Qt6 Qt5 ...) 在本机会
# 静默回退到 Qt5 导致配置失败，改为显式查找 Qt6。
set(QT_VERSION_MAJOR 6)
find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui Network Quick QuickControls2 Widgets)
find_package(Dtk6Gui REQUIRED)
find_package(Dtk6Widget REQUIRED)
find_package(X11 REQUIRED)

add_executable(xiaou-todo
    # Calendar/event editor is parked for the current version.
    # src/EventEditorController.cpp
    # src/EventEditorController.h
    src/CalendarSyncService.cpp
    src/CalendarSyncService.h
    src/NoteController.cpp
    src/NoteController.h
    src/TelemetryService.cpp
    src/TelemetryService.h
    src/TodoApp.cpp
    src/TodoApp.h
    src/main.cpp
    qml/qml.qrc
)

target_compile_definitions(xiaou-todo
    PRIVATE
        XIAOU_TODO_VERSION="${PROJECT_VERSION}"
)

target_link_libraries(xiaou-todo
    PRIVATE
        Qt${QT_VERSION_MAJOR}::Core
        Qt${QT_VERSION_MAJOR}::DBus
        Qt${QT_VERSION_MAJOR}::Gui
        Qt${QT_VERSION_MAJOR}::Network
        Qt${QT_VERSION_MAJOR}::Quick
        Qt${QT_VERSION_MAJOR}::QuickControls2
        Qt${QT_VERSION_MAJOR}::Widgets
        Dtk6::Gui
        Dtk6::Widget
        X11::X11
)

install(TARGETS xiaou-todo RUNTIME DESTINATION bin)
install(FILES xiaou-todo.desktop DESTINATION share/applications)
foreach(icon_theme hicolor bloom)
    install(FILES qml/assets/app-icons/xiaou-todo.svg
        DESTINATION share/icons/${icon_theme}/scalable/apps
        RENAME xiaou-todo.svg
    )
    install(FILES qml/assets/app-icons/xiaou-todo.svg
        DESTINATION share/icons/${icon_theme}/scalable/apps
        RENAME xiaou-todo-calendar.svg
    )
endforeach()
