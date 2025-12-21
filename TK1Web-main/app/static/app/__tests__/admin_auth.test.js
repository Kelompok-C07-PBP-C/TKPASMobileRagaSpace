/* eslint-env jest */

describe('admin_auth animations', () => {
  const originalRequestAnimationFrame = global.requestAnimationFrame;

  beforeEach(() => {
    jest.resetModules();
    document.body.innerHTML = '';
    global.requestAnimationFrame = (cb) => cb();
    delete window.anime;
    delete window.matchMedia;
  });

  afterAll(() => {
    global.requestAnimationFrame = originalRequestAnimationFrame;
  });

  test('skips animations when prefers-reduced-motion is enabled', () => {
    const anime = {
      set: jest.fn(),
    };
    window.anime = anime;
    window.matchMedia = jest.fn().mockReturnValue({ matches: true });

    require('../admin_auth.js');

    expect(anime.set).not.toHaveBeenCalled();
  });

  test('runs animations when elements exist and motion is allowed', () => {
    document.body.innerHTML = `
      <div class="card"></div>
      <div class="auth-form">
        <div>Child 1</div>
        <div>Child 2</div>
      </div>
      <div class="cloud"></div>
      <div class="cloud"></div>
    `;

    const animeFn = jest.fn((options) => {
      if (!options || !options.targets) {
        return;
      }
      const targets = Array.isArray(options.targets)
        ? options.targets
        : Array.from(options.targets);
      if (typeof options.translateY === 'function') {
        targets.forEach((_, index) => {
          options.translateY(null, index);
        });
      }
      if (typeof options.translateX === 'function') {
        targets.forEach((_, index) => {
          options.translateX(null, index);
        });
      }
    });
    const anime = Object.assign(animeFn, {
      set: jest.fn(),
      stagger: jest.fn(() => 'stagger'),
    });
    window.anime = anime;
    window.matchMedia = jest.fn().mockReturnValue({ matches: false });

    require('../admin_auth.js');

    expect(anime.set).toHaveBeenCalled();
    expect(animeFn).toHaveBeenCalled();
  });

  test('returns early when no target elements are present', () => {
    document.body.innerHTML = '';
    const animeFn = jest.fn();
    const anime = Object.assign(animeFn, {
      set: jest.fn(),
      stagger: jest.fn(() => 'stagger'),
    });
    window.anime = anime;
    window.matchMedia = jest.fn().mockReturnValue({ matches: false });

    require('../admin_auth.js');

    expect(anime.set).not.toHaveBeenCalled();
    expect(animeFn).not.toHaveBeenCalled();
  });
});

describe('admin_auth AJAX forms', () => {
  beforeEach(() => {
    jest.resetModules();
    document.body.innerHTML = '';
    delete window.fetch;
  });

  test('returns early when there are no ajax forms', () => {
    document.body.innerHTML = '<form></form>';
    const fetchMock = jest.fn();
    window.fetch = fetchMock;

    require('../admin_auth.js');

    const form = document.querySelector('form');
    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));

    expect(fetchMock).not.toHaveBeenCalled();
  });

  test('returns early when submit button is missing', async () => {
    document.body.innerHTML = `
      <form data-ajax-form action="/login">
        <input type="hidden" name="csrfmiddlewaretoken" value="token123" />
        <div data-errors></div>
      </form>
    `;

    const fetchMock = jest.fn();
    window.fetch = fetchMock;

    require('../admin_auth.js');

    const form = document.querySelector('form');
    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));

    await Promise.resolve();
    await Promise.resolve();

    expect(fetchMock).not.toHaveBeenCalled();
  });

  test('shows validation errors when response is not ok', async () => {
    document.body.innerHTML = `
      <form data-ajax-form action="/login">
        <input type="hidden" name="csrfmiddlewaretoken" value="token123" />
        <div data-errors></div>
        <button type="submit">Login</button>
      </form>
    `;

    const fetchMock = jest.fn().mockResolvedValue({
      ok: false,
      json: async () => ({ success: false, errors: ['Invalid credentials'] }),
    });
    window.fetch = fetchMock;

    require('../admin_auth.js');

    const form = document.querySelector('form');
    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));

    await Promise.resolve();
    await Promise.resolve();

    const errors = document.querySelector('[data-errors]');
    expect(errors.classList.contains('is-visible')).toBe(true);
    expect(errors.innerHTML).toContain('Invalid credentials');
  });

  test('renderErrors ignores calls when no error container is present', async () => {
    document.body.innerHTML = `
      <form data-ajax-form action="/login">
        <input type="hidden" name="csrfmiddlewaretoken" value="token123" />
        <button type="submit">Login</button>
      </form>
    `;

    const fetchMock = jest.fn().mockResolvedValue({
      ok: false,
      json: async () => ({ success: false, errors: ['Invalid credentials'] }),
    });
    window.fetch = fetchMock;

    require('../admin_auth.js');

    const form = document.querySelector('form');
    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));

    await Promise.resolve();
    await Promise.resolve();

    const errors = document.querySelector('[data-errors]');
    expect(errors).toBeNull();
  });

  test('redirects on successful submit when data-success-redirect is present', async () => {
    document.body.innerHTML = `
      <form data-ajax-form data-success-redirect action="/login">
        <input type="hidden" name="csrfmiddlewaretoken" value="token123" />
        <div data-errors></div>
        <button type="submit">Login</button>
      </form>
    `;

    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: true, redirect_url: '/dashboard' }),
    });
    window.fetch = fetchMock;

    require('../admin_auth.js');

    const form = document.querySelector('form');
    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));

    await Promise.resolve();
    await Promise.resolve();
  });

  test('shows success message without redirect when submit succeeds', async () => {
    document.body.innerHTML = `
      <form data-ajax-form action="/login">
        <input type="hidden" name="csrfmiddlewaretoken" value="token123" />
        <div data-errors></div>
        <button type="submit">Login</button>
      </form>
    `;

    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: true }),
    });
    window.fetch = fetchMock;

    require('../admin_auth.js');

    const form = document.querySelector('form');
    const button = form.querySelector('button[type="submit"]');
    const originalLabel = button.innerHTML;

    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));

    await Promise.resolve();
    await Promise.resolve();

    const errors = document.querySelector('[data-errors]');
    expect(errors.classList.contains('is-visible')).toBe(false);
    expect(button.disabled).toBe(false);
    expect(button.innerHTML).toBe(originalLabel);
  });

  test('handles network error and restores original button label', async () => {
    document.body.innerHTML = `
      <form data-ajax-form action="/login">
        <input type="hidden" name="csrfmiddlewaretoken" value="token123" />
        <div data-errors></div>
        <button type="submit">Login</button>
      </form>
    `;

    const fetchMock = jest.fn().mockRejectedValue(new Error('Network error'));
    window.fetch = fetchMock;

    require('../admin_auth.js');

    const form = document.querySelector('form');
    const button = form.querySelector('button[type="submit"]');
    const originalLabel = button.innerHTML;

    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));

    await Promise.resolve();
    await Promise.resolve();

    const errors = document.querySelector('[data-errors]');
    expect(errors.classList.contains('is-visible')).toBe(true);
    expect(errors.innerHTML).toContain('Network error');
    expect(button.disabled).toBe(false);
    expect(button.innerHTML).toBe(originalLabel);
  });
});
