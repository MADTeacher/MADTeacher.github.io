# madsite – сайт-визитка Станислава Чернышева

Личный сайт-визитка: книги, курсы на Stepik, научные публикации (ВАК), каналы
и площадки поддержки.

Чистая статика: HTML + CSS + капля vanilla JS. Никакой сборки, зависимостей и
фреймворков – сайт живёт на GitHub Pages, а при необходимости за десять минут
переезжает на любой другой статический хостинг без изменений.

**Продакшен:** https://madteacher.github.io
(репозиторий должен называться `MADTeacher.github.io` – user-pages даёт корневой URL)

## Структура

```
index.html            вся страница: шапка, книги, курсы, публикации, каналы
css/style.css         темы (светлая/тёмная) и вёрстка
js/main.js            переключатель темы + год в подвале
assets/
  covers/             обложки книг, готовые к публикации (≤480px по ширине)
  covers/src/         исходники обложек (пересжимаются скриптом)
  portrait.jpg        фото в шапке (генерируется из photo_src.jpg)
  avatar.jpg          квадратный аватар (генерируется, на сайте не используется)
  og-image.png        превью для Telegram/соцсетей 1200x630 (генерируется)
  favicon.svg|png     иконки вкладки
tools/
  make-og.ps1         генерация og-image, портрета, аватара, иконок
  resize-covers.ps1   пересжатие assets/covers/src → assets/covers (480px, JPEG q85)
  montage.ps1         контрольный лист из набора картинок (визуальная проверка)
```

## Локальный запуск

Просто открыть `index.html` в браузере – всё работает и с `file://`.

## Деплой

1. Создать пустой **публичный** репозиторий `MADTeacher.github.io`: https://github.com/new
2. Из этой папки:

   ```
   git remote add origin https://github.com/MADTeacher/MADTeacher.github.io.git
   git push -u origin main
   ```

3. Через 1–2 минуты сайт обновится на https://madteacher.github.io

## Как обновлять контент

- **Новая статья ВАК:** секция `id="publications"` в `index.html` – там лежит
  готовый шаблон `<li>` в HTML-комментарии.
- **Новый курс Stepik:** секция `id="courses"` в `index.html` – шаблон карточки
  в HTML-комментарии; ссылка вида `https://stepik.org/a/<id>`, без цен.
- **Новая книга:** скопировать ближайшую карточку `<article class="card">`,
  положить обложку в `assets/covers/src/<имя>.jpg` и прогнать
  `powershell -NoProfile -ExecutionPolicy Bypass -File tools\resize-covers.ps1`.
- **Новое фото:** заменить `assets/photo_src.jpg` и прогнать
  `powershell -NoProfile -ExecutionPolicy Bypass -File tools\make-og.ps1` –
  он пересоберёт портрет, аватар, og-image и иконки.

## Нюансы

- `assets/photo_src.jpg` – тяжёлый исходник портрета, в git не входит
  (см. `.gitignore`), скрипты генерации работают с локальной копией.
- PowerShell-скрипты хранятся в UTF-8 **с BOM**: без него Windows PowerShell 5.1
  ломает кириллицу в строках.
- Тире в текстах – только средние (–), длинные (—) не используем: в контенте
  сайта, README, комментариях и генерируемых картинках.
- Инструкции для ИИ-агентов, работающих с репозиторием, – в [AGENTS.md](AGENTS.md).
