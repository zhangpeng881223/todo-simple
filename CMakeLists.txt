cmake_minimum_required(VERSION 3.16)

project(todo260606 VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Widgets)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Gui Quick QuickControls2 Widgets)
find_package(Dtk6Gui REQUIRED)
find_package(Dtk6Widget REQUIRED)

add_executable(todo260606
    # Calendar/event editor is parked for the current version.
    # src/EventEditorController.cpp
    # src/EventEditorController.h
    src/NoteController.cpp
    src/NoteController.h
    src/TodoApp.cpp
    src/TodoApp.h
    src/main.cpp
    qml/qml.qrc
)

target_link_libraries(todo260606
    PRIVATE
        Qt${QT_VERSION_MAJOR}::Core
        Qt${QT_VERSION_MAJOR}::Gui
        Qt${QT_VERSION_MAJOR}::Quick
        Qt${QT_VERSION_MAJOR}::QuickControls2
        Qt${QT_VERSION_MAJOR}::Widgets
        Dtk6::Gui
        Dtk6::Widget
)

install(TARGETS todo260606 RUNTIME DESTINATION bin)
install(FILES todo260606.desktop DESTINATION share/applications)
install(FILES qml/assets/xiaou-todo-app-icon.png
    DESTINATION share/icons/hicolor/128x128/apps
    RENAME todo260606.png
)
