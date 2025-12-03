# Добавление новых файлов в Xcode проект

После создания новых файлов их нужно добавить в проект Xcode.

## Способ 1: Через Xcode (рекомендуется)

1. Откройте проект в Xcode
2. В Project Navigator (левая панель) найдите папку `HollowSignal`
3. Правой кнопкой мыши на папке → "Add Files to HollowSignal..."
4. Выберите следующие файлы:
   - `LLMService.swift`
   - `DataRecorder.swift`
   - `FaceTracker.swift`
5. Убедитесь, что выбрано:
   - ✅ "Copy items if needed" (если файлы не в папке проекта)
   - ✅ "Add to targets: HollowSignal"
6. Нажмите "Add"

## Способ 2: Перетаскивание

1. Откройте Finder с файлами
2. Перетащите файлы в папку `HollowSignal` в Project Navigator
3. В диалоге выберите "Copy items if needed" и "Add to targets: HollowSignal"

## Проверка

После добавления файлов убедитесь, что они:
- Видны в Project Navigator
- Имеют правильный target membership (в File Inspector справа)

Если файлы не компилируются, проверьте:
- Все импорты на месте
- Файлы добавлены в правильный target
- Нет циклических зависимостей

