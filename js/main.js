// Сайт собран без фреймворков: тут переключатель темы, год в подвале,
// внешние ссылки, открывающиеся в отдельной вкладке, и ThumbHash-заглушки
// обложек (размытый фон, пока грузится WebP).

(function () {
  var root = document.documentElement;
  var toggle = document.getElementById('theme-toggle');
  var themeColor = document.querySelector('meta[name="theme-color"]');

  function applyTheme(theme) {
    root.dataset.theme = theme;
    try { localStorage.setItem('theme', theme); } catch (e) { /* приватный режим – не страшно */ }
    toggle.setAttribute(
      'aria-label',
      theme === 'dark' ? 'Включить светлую тему' : 'Включить тёмную тему'
    );
    if (themeColor) {
      themeColor.setAttribute('content', theme === 'dark' ? '#232a2c' : '#fafaf6');
    }
  }

  toggle.addEventListener('click', function () {
    applyTheme(root.dataset.theme === 'dark' ? 'light' : 'dark');
  });

  // Синхронизируем подпись кнопки с темой, которую выставил инлайн-скрипт в <head>
  toggle.setAttribute(
    'aria-label',
    root.dataset.theme === 'dark' ? 'Включить светлую тему' : 'Включить тёмную тему'
  );
  if (themeColor) {
    themeColor.setAttribute('content', root.dataset.theme === 'dark' ? '#232a2c' : '#fafaf6');
  }

  // Внешние ссылки – в отдельной вкладке, внутренние якоря (#books и т.п.) не трогаем.
  var links = document.querySelectorAll('a[href^="http"]');
  for (var i = 0; i < links.length; i++) {
    links[i].target = '_blank';
    links[i].rel = 'noopener';
  }

  // ThumbHash-заглушки: у img с data-thumbhash подкладываем размытую картинку
  // фоном – она видна, пока основная не декодировалась (декодер в js/vendor).
  if (window.ThumbHash) {
    var placed = document.querySelectorAll('img[data-thumbhash]');
    for (var t = 0; t < placed.length; t++) {
      try {
        var bin = atob(placed[t].getAttribute('data-thumbhash'));
        var bytes = new Uint8Array(bin.length);
        for (var b = 0; b < bin.length; b++) bytes[b] = bin.charCodeAt(b);
        var dec = ThumbHash.thumbHashToRGBA(bytes);
        var cnv = document.createElement('canvas');
        cnv.width = dec.w; cnv.height = dec.h;
        cnv.getContext('2d').putImageData(
          new ImageData(new Uint8ClampedArray(dec.rgba), dec.w, dec.h), 0, 0
        );
        placed[t].style.backgroundImage = 'url(' + cnv.toDataURL() + ')';
      } catch (e) { /* кривой хэш – обложка грузится без заглушки */ }
    }
  }

  var year = document.getElementById('year');
  if (year) year.textContent = String(new Date().getFullYear());
})();
