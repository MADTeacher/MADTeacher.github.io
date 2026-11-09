// Сайт собран без фреймворков: тут переключатель темы, год в подвале
// и внешние ссылки, открывающиеся в отдельной вкладке.

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

  var year = document.getElementById('year');
  if (year) year.textContent = String(new Date().getFullYear());
})();
