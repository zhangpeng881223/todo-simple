# 待办260606

Qt + QML 重写版“小U待办”。

构建：

```bash
cmake -S . -B build
cmake --build build -j
```

运行：

```bash
DISPLAY=:0 QT_QPA_PLATFORM=xcb ./build/xiaou-todo
```

烟测打开所有窗口：

```bash
DISPLAY=:0 QT_QPA_PLATFORM=xcb ./build/xiaou-todo --show-all
```

数据目录：

```text
~/Documents/小U待办
```

本版重点先还原旧版窗口视觉和核心交互，不依赖 Electron，也不按 DTK 标准标题栏约束实现。
