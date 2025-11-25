(function () {
  const scriptEl = document.currentScript;
  const baseUrl = scriptEl
    ? scriptEl.src.slice(0, scriptEl.src.lastIndexOf('/') + 1)
    : '';
  const chunks = [
    'admin.animations.js',
    'admin.state.js',
    'admin.ui.js',
    'admin.events.js',
  ];

  function loadChunk(name) {
    const url = baseUrl + name;
    return fetch(url, { cache: 'no-cache' }).then((res) => {
      if (!res.ok) {
        throw new Error(`Failed to load ${name}: ${res.status} ${res.statusText}`);
      }
      return res.text();
    });
  }

  Promise.all(chunks.map(loadChunk))
    .then((parts) => {
      const bundle = parts.join('\n');
      // eslint-disable-next-line no-eval
      eval(bundle);
    })
    .catch((error) => {
      // Surface a clear error for admins if the bundle fails to load.
      console.error('[admin] Unable to load split bundles', error);
      const notice = document.createElement('div');
      notice.style.cssText =
        'position:fixed;bottom:16px;right:16px;padding:12px 16px;' +
        'background:#c0392b;color:#fff;border-radius:8px;z-index:9999;' +
        'box-shadow:0 10px 30px rgba(0,0,0,0.25);font-family:sans-serif;';
      notice.textContent =
        'Admin UI failed to load. Please refresh or contact support.';
      document.body.appendChild(notice);
    });
})();
