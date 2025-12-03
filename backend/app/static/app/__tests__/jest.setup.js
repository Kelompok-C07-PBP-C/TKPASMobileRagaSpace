/* Global Jest setup for admin JS tests. */

// Basic DOM-related globals that some scripts expect.
if (typeof window !== 'undefined') {
  if (!window.requestAnimationFrame) {
    window.requestAnimationFrame = (cb) => setTimeout(cb, 0);
  }
  if (!window.cancelAnimationFrame) {
    window.cancelAnimationFrame = (id) => clearTimeout(id);
  }
  if (!window.matchMedia) {
    window.matchMedia = jest.fn().mockReturnValue({ matches: false, addListener: () => {}, removeListener: () => {} });
  }
  if (!window.fetch) {
    window.fetch = jest.fn();
  }
  if (!window.localStorage) {
    let store = {};
    window.localStorage = {
      getItem: (key) => (key in store ? store[key] : null),
      setItem: (key, value) => {
        store[key] = String(value);
      },
      removeItem: (key) => {
        delete store[key];
      },
      clear: () => {
        store = {};
      },
    };
  }
}

beforeEach(() => {
  // Clean DOM and reset common mocks between tests.
  document.body.innerHTML = '';
  if (window.fetch && typeof window.fetch.mockReset === 'function') {
    window.fetch.mockReset();
  }
});

