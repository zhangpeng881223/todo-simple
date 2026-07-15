cmake_minimum_required(VERSION 3.16)

project(xiaou-todo VERSION 2.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core DBus Gui Network Quick QuickControls2 Widgets)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core DBus Gui Network Quick QuickControls2 Widgets)
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
set(XIAOU_ICON_SIZES 16 24 32 48 64 80 96 128 160 256 512 1024)
foreach(icon_size IN LISTS XIAOU_ICON_SIZES)
    foreach(icon_theme hicolor bloom)
        install(FILES qml/assets/app-icons/xiaou-todo-${icon_size}.png
            DESTINATION share/icons/${icon_theme}/${icon_size}x${icon_size}/apps
            RENAME xiaou-todo.png
        )
        install(FILES qml/assets/app-icons/xiaou-todo-${icon_size}.png
            DESTINATION share/icons/${icon_theme}/${icon_size}x${icon_size}/apps
            RENAME xiaou-todo-calendar.png
        )
    endforeach()
endforeach()
install(FILES qml/assets/app-icons/xiaou-todo-128.png
    DESTINATION share/pixmaps
    RENAME xiaou-todo.png
)
install(FILES qml/assets/app-icons/xiaou-todo-128.png
    DESTINATION share/pixmaps
    RENAME xiaou-todo-calendar.png
)
