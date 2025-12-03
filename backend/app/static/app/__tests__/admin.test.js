/* eslint-env jest */

describe('admin.js chunk loader', () => {
  beforeEach(() => {
    jest.resetModules();
  });

  function setupScriptTag(src = 'https://example.com/static/app/admin.js') {
    const script = document.createElement('script');
    script.src = src;
    // Simulate the currently executing script
    document.body.appendChild(script);
    Object.defineProperty(document, 'currentScript', {
      configurable: true,
      get() {
        return script;
      },
    });
    return script;
  }

  test('loads all chunks and evals bundle in happy path', async () => {
    const script = setupScriptTag();

    // Each chunk returns a simple statement that flips a flag.
    const chunkBodies = [
      'window.__chunkCalls = (window.__chunkCalls || []); window.__chunkCalls.push("animations");',
      'window.__chunkCalls.push("state");',
      'window.__chunkCalls.push("ui");',
      'window.__chunkCalls.push("events");',
    ];

    window.fetch.mockImplementation((url) => {
      const name = url.substring(url.lastIndexOf('/') + 1);
      const index = ['admin.animations.js', 'admin.state.js', 'admin.ui.js', 'admin.events.js'].indexOf(
        name,
      );
      if (index === -1) {
        return Promise.resolve({ ok: false, status: 404, statusText: 'Not Found' });
      }
      return Promise.resolve({
        ok: true,
        text: () => Promise.resolve(chunkBodies[index]),
      });
    });

    // Require the loader – it will immediately start fetching.
    require('../admin.js'); // eslint-disable-line global-require

    // Let Promise.all and its .then handler run.
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(window.fetch).toHaveBeenCalledTimes(4);
    // All chunk bodies should have been evaluated in order.
    expect(window.__chunkCalls).toEqual(['animations', 'state', 'ui', 'events']);

    // Clean up the fake currentScript.
    document.body.removeChild(script);
  });

  test('renders a visible error banner when a chunk fails to load', async () => {
    setupScriptTag();

    // Simulate a network-layer error (Promise rejection).
    const error = new Error('network fail');
    window.fetch.mockRejectedValue(error);
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

    require('../admin.js'); // eslint-disable-line global-require

    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(consoleErrorSpy).toHaveBeenCalled();
    const banner = document.body.querySelector('div');
    expect(banner).not.toBeNull();
    expect(banner.textContent).toMatch(/Admin UI failed to load/i);

    consoleErrorSpy.mockRestore();
  });

  test('handles non-ok chunk responses by throwing and surfacing an error', async () => {
    setupScriptTag();

    // First chunk returns a 500 response, triggering the `throw new Error(...)` line.
    window.fetch.mockImplementation((url) =>
      Promise.resolve({
        ok: false,
        status: 500,
        statusText: 'Server Error',
        text: () => Promise.resolve(''),
      }),
    );

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

    require('../admin.js'); // eslint-disable-line global-require

    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(window.fetch).toHaveBeenCalledTimes(4);
    // Even though the first chunk fails, the loader should catch and log.
    expect(consoleErrorSpy).toHaveBeenCalled();
    const banner = document.body.querySelector('div');
    expect(banner).not.toBeNull();
    expect(banner.textContent).toMatch(/Admin UI failed to load/i);

    consoleErrorSpy.mockRestore();
  });
});
