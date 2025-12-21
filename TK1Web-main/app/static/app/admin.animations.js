(function () {
  const reduceMotionQuery =
    typeof window.matchMedia === 'function'
      ? window.matchMedia('(prefers-reduced-motion: reduce)')
      : null;
  const reduceMotion = reduceMotionQuery && reduceMotionQuery.matches;
  if (reduceMotion || typeof anime === 'undefined') {
    return;
  }

  const sidebar = document.querySelector('.sidebar');
  const navButtons = document.querySelectorAll('.sidebar-nav .nav-link');
  const contentHeader = document.querySelector('.content-header');
  const surfaceCards = document.querySelectorAll('.surface-card');

  if (!sidebar && !navButtons.length && !contentHeader && !surfaceCards.length) {
    return;
  }

  if (sidebar) {
    anime.set(sidebar, { opacity: 0, translateX: -32 });
  }
  if (navButtons.length) {
    anime.set(navButtons, { opacity: 0, translateX: -12 });
  }
  if (contentHeader) {
    anime.set(contentHeader, { opacity: 0, translateY: -16 });
  }
  if (surfaceCards.length) {
    anime.set(surfaceCards, { opacity: 0, translateY: 24 });
  }

  const timeline = anime.timeline({ easing: 'easeOutQuad', duration: 620, autoplay: false });

  if (sidebar) {
    timeline.add({ targets: sidebar, opacity: 1, translateX: 0 });
  }

  if (navButtons.length) {
    timeline.add(
      {
        targets: navButtons,
        opacity: 1,
        translateX: 0,
        delay: anime.stagger(80),
      },
      sidebar ? '-=320' : 0,
    );
  }

  if (contentHeader) {
    timeline.add(
      {
        targets: contentHeader,
        opacity: 1,
        translateY: 0,
      },
      sidebar || navButtons.length ? '-=360' : 0,
    );
  }

  if (surfaceCards.length) {
    timeline.add(
      {
        targets: surfaceCards,
        opacity: 1,
        translateY: 0,
        delay: anime.stagger(140),
      },
      '-=260',
    );
  }

  if (timeline.children && timeline.children.length) {
    timeline.play();
  }
})();

(function () {
  const app = document.getElementById('admin-app');
  if (!app) {
    return;
  }

  const sidebarToggle = app.querySelector('[data-action="toggle-sidebar"]');
  const sidebarToggleKey = 'admin.sidebar.collapsed';

  const endpoints = {
    venues: {
      list: '/api/admin/venues/',
      create: '/api/admin/venues/create/',
      update: (id) => `/api/admin/venues/${id}/update/`,
      delete: (id) => `/api/admin/venues/${id}/delete/`,
    },
    bookings: {
      list: '/api/admin/bookings/',
      create: '/api/admin/bookings/create/',
      update: (id) => `/api/admin/bookings/${id}/update/`,
      delete: (id) => `/api/admin/bookings/${id}/delete/`,
    },
    users: {
      search: '/api/admin/users/search/',
    },
  };

  const DEFAULT_PAGE_SIZE = 6;

  const sectionConfig = {
    venues: {
      title: 'Venues',
      description: 'Manage your venues, pricing, facilities, and imagery in real time.',
      buttonLabel: 'Add venue',
      emptyMessage: 'No venues available yet.',
    },
    bookings: {
      title: 'Bookings',
      description: 'Review reservations, payment status, and stay details instantly.',
      buttonLabel: 'Add booking',
      emptyMessage: 'No bookings recorded yet.',
    },
  };

  const state = {
    venues: [],
    bookings: [],
    currentSection: 'venues',
    modalMode: 'create',
    editingId: null,
    hasUsers: app.dataset.hasUsers === 'true',
    sort: {
      venues: { key: null, direction: 'asc' },
      bookings: { key: 'created', direction: 'desc' },
    },
    pagination: {
      venues: {
        page: 1,
        pageSize: DEFAULT_PAGE_SIZE,
        totalPages: 1,
        totalItems: 0,
        hasPrevious: false,
        hasNext: false,
        query: '',
      },
      bookings: {
        page: 1,
        pageSize: DEFAULT_PAGE_SIZE,
        totalPages: 1,
        totalItems: 0,
        hasPrevious: false,
        hasNext: false,
        query: '',
      },
    },
    search: {
      venues: '',
      bookings: '',
    },
  };

  function parseInitialData(id) {
    const script = document.getElementById(id);
    if (!script) {
      return null;
    }
    try {
      return JSON.parse(script.textContent);
    } catch (error) {
      console.error(`Failed to parse initial data for ${id}`, error);
      return null;
    }
  }

  function parseInitialPayload(id) {
    const raw = parseInitialData(id);
    if (Array.isArray(raw)) {
      return { data: raw, meta: {} };
    }
    if (raw && typeof raw === 'object') {
      const data = Array.isArray(raw.data) ? raw.data : [];
      const meta = raw.meta && typeof raw.meta === 'object' ? raw.meta : {};
      return { data, meta };
    }
    return { data: [], meta: {} };
  }

  function normalizeSeries(raw) {
    const source = raw && typeof raw === 'object' ? raw : {};
    const rawLabels = Array.isArray(source.labels) ? source.labels : [];
    const rawData = Array.isArray(source.data) ? source.data : [];
    const length = Math.min(rawLabels.length, rawData.length);
    const labels = [];
    const data = [];
    for (let index = 0; index < length; index += 1) {
      labels.push(String(rawLabels[index]));
      const numeric = Number(rawData[index]);
      data.push(Number.isFinite(numeric) ? numeric : 0);
    }
    return { labels, data };
  }

  function formatDateTimeLocal(value) {
    /*
     * Normalize incoming ISO strings for <input type="datetime-local">.
     * We snap minutes/seconds to :00 so that the picker effectively
     * works with hourly slots (hours only, no minute precision).
     */
    if (!value) {
      return '';
    }
    const date = new Date(String(value));
    if (!Number.isNaN(date.getTime())) {
      date.setMinutes(0, 0, 0);
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const hour = String(date.getHours()).padStart(2, '0');
      return `${year}-${month}-${day}T${hour}:00`;
    }
    const stringValue = String(value);
    if (stringValue.length >= 16) {
      // Fallback: keep date + hour, zero out minutes
      const base = stringValue.slice(0, 13).replace(' ', 'T');
      return `${base}:00`;
    }
    return stringValue.replace(' ', 'T');
  }

  const initialVenues = parseInitialPayload('initial-venues');
  const initialBookings = parseInitialPayload('initial-bookings');
  const initialSalesData = parseInitialData('sales-chart-data');
  const initialPopularityData = parseInitialData('popularity-chart-data');
  const analyticsData = {
    sales: normalizeSeries(initialSalesData),
    popularity: normalizeSeries(initialPopularityData),
  };

  state.venues = initialVenues.data;
  state.bookings = initialBookings.data;
  state.pagination.venues = normalizePaginationMeta(
    initialVenues.meta,
    state.pagination.venues,
  );
  state.pagination.bookings = normalizePaginationMeta(
    initialBookings.meta,
    state.pagination.bookings,
  );
  state.search.venues = state.pagination.venues.query;
  state.search.bookings = state.pagination.bookings.query;

  if (initialBookings.meta && typeof initialBookings.meta.has_users === 'boolean') {
    state.hasUsers = initialBookings.meta.has_users;
  }

  const navButtons = app.querySelectorAll('.nav-link');
  const contentSections = app.querySelectorAll('.data-section');
  const sectionTitle = app.querySelector('[data-section-title]');
  const sectionDescription = app.querySelector('[data-section-description]');
  const actionButton = app.querySelector('[data-action="open-modal"]');
  const venuesTableBody = document.getElementById('venues-table-body');
  const bookingsTableBody = document.getElementById('bookings-table-body');
  const emptyStates = {
    venues: document.querySelector('[data-empty="venues"]'),
    bookings: document.querySelector('[data-empty="bookings"]'),
  };
  const tableWrappers = {
    venues: document.querySelector('[data-table-wrapper="venues"]'),
    bookings: document.querySelector('[data-table-wrapper="bookings"]'),
  };
  const searchInputs = {
    venues: document.querySelector('[data-search-input="venues"]'),
    bookings: document.querySelector('[data-search-input="bookings"]'),
  };
  const paginationContainers = {
    venues: document.querySelector('[data-pagination="venues"]'),
    bookings: document.querySelector('[data-pagination="bookings"]'),
  };
  const tableSummaries = {
    venues: document.querySelector('[data-summary="venues"]'),
    bookings: document.querySelector('[data-summary="bookings"]'),
  };
  const tableFooters = {
    venues: document.querySelector('[data-table-footer="venues"]'),
    bookings: document.querySelector('[data-table-footer="bookings"]'),
  };
  const sortableHeaders = {
    venues: Array.from(
      app.querySelectorAll('[data-sort-section="venues"][data-sort-key]'),
    ),
    bookings: Array.from(
      app.querySelectorAll('[data-sort-section="bookings"][data-sort-key]'),
    ),
  };
  const chartElements = {
    sales: {
      canvas: document.getElementById('venue-sales-chart'),
      empty: document.querySelector('[data-chart-empty="sales"]'),
    },
    popularity: {
      canvas: document.getElementById('venue-popularity-chart'),
      empty: document.querySelector('[data-chart-empty="popularity"]'),
    },
  };
  const chartInstances = {
    sales: null,
    popularity: null,
  };
  const modalBackdrop = document.querySelector('[data-modal]');
  const modalElement = modalBackdrop ? modalBackdrop.querySelector('.modal') : null;
  const modalTitle = document.getElementById('modal-title');
  const entityForm = document.getElementById('entity-form');
  const modalErrors = document.querySelector('[data-modal-errors]');
  const submitLabel = entityForm.querySelector('[data-submit-label]');
  const toast = document.getElementById('toast');
  const formSections = {
    venues: entityForm.querySelector('[data-form="venues"]'),
    bookings: entityForm.querySelector('[data-form="bookings"]'),
  };
  const autocompleteControllers = {};
  let userSearchController = null;
  const fetchControllers = {
    venues: null,
    bookings: null,
  };
  const searchTimeouts = {
    venues: null,
    bookings: null,
  };

  const reduceMotionQuery = typeof window.matchMedia === 'function' ? window.matchMedia('(prefers-reduced-motion: reduce)') : null;
  const prefersReducedMotion = reduceMotionQuery ? reduceMotionQuery.matches : false;
  const canAnimate = typeof anime !== 'undefined' && !prefersReducedMotion;
  let modalAnimation = null;

  function toggleFormSection(section, isActive) {
    if (!section) {
      return;
    }
    const fields = section.querySelectorAll('input, select, textarea');
    fields.forEach((field) => {
      field.disabled = !isActive;
    });
  }

  function setActiveFormSection(section) {
    Object.entries(formSections).forEach(([key, element]) => {
      const isActive = key === section;
      if (element) {
        element.classList.toggle('is-hidden', !isActive);
        toggleFormSection(element, isActive);
      }
    });
  }

  setActiveFormSection('venues');

  function resetModalStyles() {
    if (modalBackdrop) {
      modalBackdrop.style.removeProperty('opacity');
    }
    if (modalElement) {
      modalElement.style.removeProperty('opacity');
      modalElement.style.removeProperty('transform');
    }
  }

  function showModalBackdrop() {
    if (!modalBackdrop) {
      return;
    }
    modalBackdrop.hidden = false;
    modalBackdrop.setAttribute('aria-hidden', 'false');
    if (document.body) {
      document.body.classList.add('modal-open');
    }
  }

  function hideModalBackdrop() {
    if (!modalBackdrop) {
      return;
    }
    modalBackdrop.hidden = true;
    modalBackdrop.setAttribute('aria-hidden', 'true');
    if (document.body) {
      document.body.classList.remove('modal-open');
    }
  }

  function animateActiveNavButton(button) {
    if (!canAnimate || !button) {
      return;
    }
    anime.remove(button);
    anime.set(button, { scale: 0.94 });
    anime({
      targets: button,
      scale: 1,
      duration: 220,
      easing: 'easeOutQuad',
      complete: () => {
        button.style.removeProperty('transform');
      },
    });
  }

  function animateSectionEntry(sectionElement) {
    if (!canAnimate || !sectionElement) {
      return;
    }
    anime.remove(sectionElement);
    anime.set(sectionElement, { opacity: 0, translateY: 18 });
    requestAnimationFrame(() => {
      anime({
        targets: sectionElement,
        opacity: 1,
        translateY: 0,
        duration: 360,
        easing: 'easeOutQuad',
        complete: () => {
          sectionElement.style.removeProperty('opacity');
          sectionElement.style.removeProperty('transform');
        },
      });
    });
  }

  function animateTableRows(container) {
    if (!canAnimate || !container) {
      return;
    }
    const rows = Array.from(container.querySelectorAll('tr'));
    if (!rows.length) {
      return;
    }
    anime.remove(rows);
    anime.set(rows, { opacity: 0, translateY: 12 });
    requestAnimationFrame(() => {
      anime({
        targets: rows,
        opacity: 1,
        translateY: 0,
        duration: 320,
        easing: 'easeOutQuad',
        delay: anime.stagger(40),
        complete: () => {
          rows.forEach((row) => {
            row.style.removeProperty('opacity');
            row.style.removeProperty('transform');
          });
        },
      });
    });
  }

  function animateRowRemoval(section, recordId) {
    if (!canAnimate) {
      return Promise.resolve();
    }
    const container = section === 'venues' ? venuesTableBody : bookingsTableBody;
    if (!container) {
      return Promise.resolve();
    }
    const row = container.querySelector(`tr[data-record-id="${recordId}"]`);
    if (!row) {
      return Promise.resolve();
    }
    anime.remove(row);
    return new Promise((resolve) => {
      anime({
        targets: row,
        opacity: 0,
        translateX: 28,
        duration: 220,
        easing: 'easeInQuad',
        complete: () => {
          row.remove();
          resolve();
        },
      });
    });
  }

  function normalizePaginationMeta(meta = {}, fallback = {}) {
    const resolved = meta && typeof meta === 'object' ? meta : {};
    const fallbackMeta = fallback && typeof fallback === 'object' ? fallback : {};
    const parseNumber = (value, defaultValue) => {
      const parsed = Number.parseInt(value, 10);
      if (!Number.isFinite(parsed) || parsed <= 0) {
        return defaultValue;
      }
      return parsed;
    };

    let page = parseNumber(resolved.page ?? fallbackMeta.page, fallbackMeta.page ?? 1);
    let pageSize = parseNumber(resolved.page_size ?? resolved.pageSize ?? fallbackMeta.pageSize, fallbackMeta.pageSize ?? DEFAULT_PAGE_SIZE);
    let totalPages = parseNumber(resolved.total_pages ?? resolved.totalPages ?? fallbackMeta.totalPages, fallbackMeta.totalPages ?? 1);
    let totalItems = parseNumber(resolved.total_items ?? resolved.totalItems ?? fallbackMeta.totalItems, fallbackMeta.totalItems ?? 0);

    if (!Number.isFinite(page) || page < 1) {
      page = 1;
    }
    if (!Number.isFinite(pageSize) || pageSize < 1) {
      pageSize = DEFAULT_PAGE_SIZE;
    }
    if (!Number.isFinite(totalPages) || totalPages < 1) {
      totalPages = 1;
    }
    if (!Number.isFinite(totalItems) || totalItems < 0) {
      totalItems = 0;
    }
    if (page > totalPages) {
      page = totalPages;
    }

    const rawHasPrevious = resolved.has_previous ?? resolved.hasPrevious ?? fallbackMeta.hasPrevious ?? fallbackMeta.has_previous;
    const rawHasNext = resolved.has_next ?? resolved.hasNext ?? fallbackMeta.hasNext ?? fallbackMeta.has_next;

    const normalized = {
      page,
      pageSize,
      totalPages,
      totalItems,
      hasPrevious: typeof rawHasPrevious === 'boolean' ? rawHasPrevious : page > 1 && totalPages > 1,
      hasNext: typeof rawHasNext === 'boolean' ? rawHasNext : page < totalPages,
      query: typeof resolved.query === 'string' ? resolved.query.trim() : typeof fallbackMeta.query === 'string' ? fallbackMeta.query.trim() : '',
    };

    const ignoredKeys = new Set([
      'page',
      'page_size',
      'pageSize',
      'total_pages',
      'totalPages',
      'total_items',
      'totalItems',
      'has_previous',
      'hasPrevious',
      'has_next',
      'hasNext',
      'query',
    ]);

    [fallbackMeta, resolved].forEach((source) => {
      if (!source || typeof source !== 'object') {
        return;
      }
      Object.entries(source).forEach(([key, value]) => {
        if (!ignoredKeys.has(key) && !(key in normalized)) {
          normalized[key] = value;
        }
      });
    });

    return normalized;
  }

  function getAddonElements() {
    if (!entityForm) {
      return { field: null, list: null, input: null, empty: null };
    }
    const activeSectionKey = entityForm.dataset.section || 'venues';
    const container =
      (formSections && formSections[activeSectionKey]) || entityForm;
    return {
      field: container.querySelector('[data-addons-field]'),
      list: container.querySelector('[data-addons-list]'),
      input: container.querySelector('[data-addons-input]'),
      empty: container.querySelector('[data-addons-empty]'),
    };
  }

  function getAddonsButtonForSection(section) {
    if (!entityForm) {
      return null;
    }
    const container =
      (formSections && formSections[section]) || entityForm;
    if (!container) {
      return null;
    }
    return container.querySelector('[data-addons-add]');
  }

  function getCurrentVenueId() {
    if (!entityForm) {
      return null;
    }
    const hiddenInput = entityForm.querySelector('input[name="venue"]');
    if (hiddenInput && hiddenInput.value) {
      const parsed = Number.parseInt(hiddenInput.value, 10);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
    if (
      autocompleteControllers.venue
      && autocompleteControllers.venue.hiddenInput
      && autocompleteControllers.venue.hiddenInput.value
    ) {
      const parsed = Number.parseInt(
        autocompleteControllers.venue.hiddenInput.value,
        10,
      );
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
    return null;
  }

  function setCurrentVenuePrice(price) {
    if (!entityForm) {
      return;
    }
    const hiddenInput = entityForm.querySelector('input[name="venue"]');
    if (!hiddenInput) {
      return;
    }
    if (Number.isFinite(price)) {
      hiddenInput.dataset.price = String(price);
    } else {
      delete hiddenInput.dataset.price;
    }
  }

  function getAddonRows() {
    const { list } = getAddonElements();
    if (!list) {
      return [];
    }
    return Array.from(list.querySelectorAll('[data-addon-row]'));
  }

  function updateAddonLabels() {
    const rows = getAddonRows();
    rows.forEach((row, index) => {
      const label = row.querySelector('[data-addon-label]');
      if (label) {
        label.textContent = `Addon #${index + 1}`;
      }
    });
  }

  function updateAddonEmptyState() {
    const { empty } = getAddonElements();
    if (!empty) {
      return;
    }
    empty.classList.toggle('is-hidden', getAddonRows().length > 0);
  }

  function createAddonRow(addon = {}) {
    const row = document.createElement('div');
    row.className = 'addon-card';
    row.dataset.addonRow = 'true';

    const isBookingContext =
      entityForm && entityForm.dataset.section === 'bookings';

    if (isBookingContext) {
      row.innerHTML = 
        `<div class="addon-card__header">
          <p class="addon-card__title" data-addon-label>Addon #1</p>
          <button class="icon-btn" type="button" data-action="remove-addon" aria-label="Remove add-on">×</button>
        </div>
        <div class="addon-card__body">
          <div class="addon-card__inputs">
            <label class="addon-card__select">
              <span>Add-on name</span>
              <select data-addon-name>
                <option value="">Choose an add-on</option>
              </select>
            </label>
            <label>
              <span>Price</span>
              <input type="number" data-addon-price min="0" placeholder="75000" readonly />
            </label>
          </div>
          <label class="addon-card__description">
            <span>Description</span>
            <textarea data-addon-description rows="2" placeholder="Describe what guests receive." readonly></textarea>
          </label>
        </div>`
      ;
    } else {
      row.innerHTML = 
        `<div class="addon-card__header">
          <p class="addon-card__title" data-addon-label>Addon #1</p>
          <button class="icon-btn" type="button" data-action="remove-addon" aria-label="Remove add-on">×</button>
        </div>
        <div class="addon-card__body">
          <div class="addon-card__inputs">
            <label>
              <span>Add-on name</span>
              <input type="text" data-addon-name maxlength="255" placeholder="Premium coach session" />
            </label>
            <label>
              <span>Price</span>
              <input type="number" data-addon-price min="0" placeholder="75000" />
            </label>
          </div>
          <label class="addon-card__description">
            <span>Description</span>
            <textarea data-addon-description rows="2" placeholder="Describe what guests receive."></textarea>
          </label>
        </div>`
      ;
    }

    const nameField = row.querySelector('[data-addon-name]');
    const priceField = row.querySelector('[data-addon-price]');
    const descField = row.querySelector('[data-addon-description]');

    if (!isBookingContext && nameField) {
      nameField.value = addon && typeof addon.name === 'string' ? addon.name : '';
    }
    if (!isBookingContext && priceField) {
      const priceValue = Number.parseInt(
        addon && addon.price !== undefined ? addon.price : '',
        10,
      );
      priceField.value =
        Number.isFinite(priceValue) && priceValue >= 0
          ? String(priceValue)
          : '';
    }
    if (!isBookingContext && descField) {
      descField.value =
        addon && typeof addon.description === 'string'
          ? addon.description
          : '';
    }

    return row;
  }

  function collectAddonFormData() {
    const payload = [];
    getAddonRows().forEach((row) => {
      const nameField = row.querySelector('[data-addon-name]');
      const priceField = row.querySelector('[data-addon-price]');
      const descriptionField = row.querySelector('[data-addon-description]');
      const name = nameField ? nameField.value.trim() : '';
      if (!name) {
        return;
      }
      const parsedPrice = Number.parseInt(priceField ? priceField.value : '', 10);
      payload.push({
        name,
        price: Number.isFinite(parsedPrice) && parsedPrice >= 0 ? parsedPrice : 0,
        description: descriptionField ? descriptionField.value.trim() : '',
      });
    });
    return payload;
  }

  function syncAddonsInput() {
    const { input } = getAddonElements();
    if (!input) {
      return;
    }
    const payload = collectAddonFormData();
    input.value = JSON.stringify(payload);
  }

  function appendAddonRow(addon = {}) {
    const { list } = getAddonElements();
    if (!list) {
      return null;
    }
    const row = createAddonRow(addon);
    if (entityForm && entityForm.dataset.section === 'bookings') {
      initializeBookingAddonRow(row, addon);
    }
    list.appendChild(row);

    updateAddonLabels();
    updateAddonEmptyState();
    syncAddonsInput();
    if (entityForm && entityForm.dataset.section === 'bookings') {
      updateBookingAddonOptionStates();
    }
    return row;
  }

  function initializeBookingAddonRow(row, addon = {}) {
    if (!entityForm || entityForm.dataset.section !== 'bookings') {
      return;
    }
    if (!row) {
      return;
    }
    const select = row.querySelector('select[data-addon-name]');
    const priceInput = row.querySelector('[data-addon-price]');
    const descriptionInput = row.querySelector('[data-addon-description]');
    if (!select || !priceInput || !descriptionInput) {
      return;
    }
    const addons = getCurrentVenueAddons();
    select.innerHTML = '';
    const placeholder = document.createElement('option');
    placeholder.value = '';
    placeholder.textContent = addons.length
      ? 'Choose an add-on'
      : 'No add-ons available';
    placeholder.disabled = true;
    placeholder.selected = true;
    placeholder.hidden = addons.length > 0;
    select.appendChild(placeholder);

    const applySelection = (source) => {
      const priceValue =
        source && source.price !== undefined ? Number(source.price) : NaN;
      priceInput.value =
        Number.isFinite(priceValue) && priceValue >= 0
          ? String(priceValue)
          : '';
      descriptionInput.value =
        source && typeof source.description === 'string'
          ? source.description
          : '';
    };

    if (!addons.length) {
      select.disabled = true;
      applySelection(null);
      return;
    }

    select.disabled = false;
    addons.forEach((item) => {
      const option = document.createElement('option');
      option.value = item && item.name ? String(item.name) : '';
      option.textContent = option.value || 'Untitled add-on';
      select.appendChild(option);
    });

    const initialName =
      addon && typeof addon.name === 'string' ? addon.name : '';
    if (initialName) {
      const matched = addons.find((item) =>
        item
        && item.name
        && String(item.name).trim().toLowerCase()
          === initialName.trim().toLowerCase(),
      );
      if (matched) {
        placeholder.selected = false;
        select.value = matched.name;
        applySelection(matched);
      } else {
        applySelection(addon);
      }
    } else {
      applySelection(null);
    }

    select.addEventListener('change', () => {
      const value = select.value || '';
      if (!value) {
        applySelection(null);
      } else {
        const matched = addons.find((item) =>
          item
          && item.name
          && String(item.name).trim().toLowerCase() === value.trim().toLowerCase(),
        );
        applySelection(matched || null);
      }
      syncAddonsInput();
      updateBookingSubtotalDisplay();
      updateBookingAddonOptionStates();
    });
  }


  function hydrateAddonsField(addons = []) {
    const { list, input } = getAddonElements();
    if (!list) {
      if (input) {
        input.value = '[]';
      }
      return;
    }
    list.innerHTML = '';
    if (Array.isArray(addons) && addons.length) {
      addons.forEach((addon) => appendAddonRow(addon));
    }
    updateAddonLabels();
    updateAddonEmptyState();
    syncAddonsInput();
    updateBookingSubtotalDisplay();
    updateBookingAddonOptionStates();
  }

  hydrateAddonsField([]);
  window.__adminAddAddon = (event) => {
    const targetButton = event ? event.currentTarget || event.target : null;
    if (targetButton && targetButton.disabled) {
      if (event) {
        event.preventDefault();
        event.stopPropagation();
      }
      return;
    }
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }
    const row = appendAddonRow();
    if (row) {
      const nameField = row.querySelector('[data-addon-name]');
      if (nameField) {
        nameField.focus();
      }
    }
  };

  document.addEventListener('click', (event) => {
    const target = event.target.closest('[data-action="remove-addon"]');
    if (!target) {
      return;
    }
    const { list } = getAddonElements();
    if (!list || !list.contains(target)) {
      return;
    }
    const row = target.closest('[data-addon-row]');
    if (row) {
      row.remove();
      updateAddonLabels();
      updateAddonEmptyState();
      syncAddonsInput();
      updateBookingAddonOptionStates();
      updateBookingSubtotalDisplay();
    }
  });

  document.addEventListener('input', (event) => {
    if (!event.target.matches('[data-addon-name], [data-addon-price], [data-addon-description]')) {
      return;
    }
    const { list } = getAddonElements();
    if (!list || !list.contains(event.target)) {
      return;
    }
    syncAddonsInput();
  });

  function getCurrentVenueAddons() {
    const venueId = getCurrentVenueId();
    if (venueId == null) {
      return [];
    }
    const venue = state.venues.find(
      (item) => Number(item.id) === Number(venueId),
    );
    if (!venue || !Array.isArray(venue.addons)) {
      return [];
    }
    return venue.addons;
  }

  function getBookingAddonElements() {
    if (!entityForm || entityForm.dataset.section !== 'bookings') {
      return {
        field: null,
        list: null,
        empty: null,
        input: null,
      };
    }
    const container =
      (formSections && formSections.bookings) || entityForm;
    return {
      field: container.querySelector('[data-addons-field]'),
      list: container.querySelector('[data-addons-list]'),
      empty: container.querySelector('[data-addons-empty]'),
      input: container.querySelector('[data-addons-input]'),
    };
  }

  function getBookingAddonSelects() {
    if (!entityForm || entityForm.dataset.section !== 'bookings') {
      return [];
    }
    const { list } = getBookingAddonElements();
    if (!list) {
      return [];
    }
    return Array.from(list.querySelectorAll('select[data-addon-name]'));
  }

  function getBookingSubtotalField() {
    if (!entityForm) {
      return null;
    }
    const container =
      (formSections && formSections.bookings) || entityForm;
    return container.querySelector('[data-booking-subtotal]');
  }

  function computeBookingSubtotal() {
    if (!entityForm) {
      return 0;
    }
    const container =
      (formSections && formSections.bookings) || entityForm;
    const startInput = container.querySelector('input[name="start_date"]');
    const endInput = container.querySelector('input[name="end_date"]');
    if (!startInput || !endInput) {
      return 0;
    }
    const startRaw = (startInput.value || '').trim();
    const endRaw = (endInput.value || '').trim();
    if (!startRaw || !endRaw) {
