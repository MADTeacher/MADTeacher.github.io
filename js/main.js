// Сайт собран без фреймворков: тут только переключатель темы и год в подвале.

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

  var year = document.getElementById('year');
  if (year) year.textContent = String(new Date().getFullYear());
})();
