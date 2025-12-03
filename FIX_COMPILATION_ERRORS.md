# Исправление ошибок компиляции

## Проблема: Файлы не найдены

Ошибки возникают потому, что новые файлы (`LLMService.swift`, `DataRecorder.swift`, `FaceTracker.swift`) не добавлены в проект Xcode.

## Решение

### Шаг 1: Добавьте файлы в проект

1. Откройте Xcode
2. В Project Navigator (левая панель) найдите папку `HollowSignal`
3. **Правой кнопкой мыши** на папке `HollowSignal` → **"Add Files to HollowSignal..."**
4. В Finder перейдите в папку проекта и выберите эти файлы:
   - `LLMService.swift`
   - `DataRecorder.swift`
   - `FaceTracker.swift`
5. В диалоге добавления файлов убедитесь, что выбрано:
   - ✅ **"Copy items if needed"** (если файлы не в папке проекта)
   - ✅ **"Add to targets: HollowSignal"**
6. Нажмите **"Add"**

### Шаг 2: Проверьте Target Membership

После добавления файлов:

1. Выберите каждый файл в Project Navigator
2. Откройте File Inspector (правая панель, ⌘⌥1)
3. В разделе "Target Membership" убедитесь, что стоит галочка напротив **"HollowSignal"**

### Шаг 3: Очистите и пересоберите

1. В Xcode: **Product** → **Clean Build Folder** (⇧⌘K)
2. **Product** → **Build** (⌘B)

## Альтернативный способ: Перетаскивание

1. Откройте Finder с файлами проекта
2. Перетащите файлы `LLMService.swift`, `DataRecorder.swift`, `FaceTracker.swift` в папку `HollowSignal` в Project Navigator
3. В диалоге выберите:
   - ✅ "Copy items if needed"
   - ✅ "Add to targets: HollowSignal"
4. Нажмите "Finish"

## Если ошибки остаются

### Проверьте импорты

Убедитесь, что в файлах есть правильные импорты:

**LLMService.swift:**
```swift
import Foundation
import Combine
```

**DataRecorder.swift:**
```swift
import Foundation
import CoreLocation
import AVFoundation
import CoreMotion
import UIKit
```

**FaceTracker.swift:**
```swift
import Foundation
import Vision
import AVFoundation
import UIKit
```

### Проверьте, что файлы скомпилированы

1. Выберите файл в Project Navigator
2. Посмотрите на иконку файла - если она красная или серая, файл не добавлен правильно
3. Попробуйте удалить файл из проекта (Delete → Remove Reference) и добавить заново

## После исправления

После добавления файлов все ошибки должны исчезнуть. Если остаются ошибки типов, убедитесь, что:

1. Все файлы добавлены в правильный target
2. Проект пересобран (Clean Build Folder)
3. Нет циклических зависимостей между файлами

