      return 0;
    }
    const startDateTime = new Date(startRaw);
    const endDateTime = new Date(endRaw);
    if (Number.isNaN(startDateTime.getTime()) || Number.isNaN(endDateTime.getTime())) {
      return 0;
    }

    let first = startDateTime;
    let last = endDateTime;
    if (last < first) {
      const tmp = first;
      first = last;
      last = tmp;
    }
    const msPerHour = 60 * 60 * 1000;
    const rawHours = (last - first) / msPerHour;
    const hours = Math.max(1, Math.round(rawHours));

    let pricePerSession = 0;
    const venueId = getCurrentVenueId();
    if (venueId != null) {
      const venue = state.venues.find((item) => Number(item.id) === Number(venueId));
      if (venue && Number.isFinite(Number(venue.price))) {
        pricePerSession = Number(venue.price);
      }
    }

    let addonsTotal = 0;
    const addons = collectAddonFormData();
    addons.forEach((addon) => {
      const price = Number(addon && addon.price);
      if (Number.isFinite(price) && price > 0) {
        addonsTotal += price;
      }
    });

    const base = hours > 0 && pricePerSession > 0 ? hours * pricePerSession : 0;
    return base + addonsTotal;
  }

  function updateBookingSubtotalDisplay() {
    const field = getBookingSubtotalField();
    if (!field) {
      return;
    }
    const subtotal = computeBookingSubtotal();
    if (!Number.isFinite(subtotal) || subtotal <= 0) {
      field.value = '';
      return;
    }
    field.value = formatCurrency(subtotal);
  }

  function updateBookingAddonOptionStates() {
    if (!entityForm || entityForm.dataset.section !== 'bookings') {
      return;
    }
    const selects = getBookingAddonSelects();
    if (!selects.length) {
      return;
    }

    const owners = new Map();
    selects.forEach((select) => {
      const value = (select.value || '').trim().toLowerCase();
      if (!value) return;
      if (!owners.has(value)) owners.set(value, select);
    });

    selects.forEach((select) => {
      const options = select.querySelectorAll('option');
      options.forEach((option) => {
        const optionValue = (option.value || '').trim().toLowerCase();
        if (!optionValue) {
          // keep placeholder behaviour as defined when creating it
          return;
        }
        const owner = owners.get(optionValue);
        option.disabled = Boolean(owner && owner !== select);
      });
    });
  }

  function setBookingAddonsAvailability(hasAddons, venueId) {
    const button = getAddonsButtonForSection('bookings');
    if (!button) {
      return;
    }
    const { field } = getBookingAddonElements();
    const disabled = !hasAddons;
    button.disabled = disabled;
    button.classList.toggle('is-disabled', disabled);
    if (field) {
      field.classList.toggle('addons-disabled', disabled);
    }
    if (disabled) {
      button.title =
        venueId == null
          ? 'Select a venue before adding add-ons.'
          : 'This venue has no add-ons configured.';
    } else {
      button.title = '';
    }
  }

  function syncSelectedBookingAddons() {
    const { input } = getBookingAddonElements();
    if (!input) {
      return;
    }
    const payload = collectAddonFormData();
    input.value = JSON.stringify(payload);
  }

  function getCsrfToken() {
    const cookie = document.cookie
      .split(';')
      .map((item) => item.trim())
      .find((item) => item.startsWith('csrftoken='));
    return cookie ? decodeURIComponent(cookie.split('=')[1]) : '';
  }

  function formatCurrency(value, { compact = false } = {}) {
    /*
     * Format amounts in Indonesian Rupiah.
     * We rely on the browser locale to render the "Rp" symbol correctly.
     */
    const options = {
      style: 'currency',
      currency: 'IDR',
      maximumFractionDigits: 0,
    };

    if (compact) {
      options.notation = 'compact';
      options.compactDisplay = 'short';
    }

    return new Intl.NumberFormat(undefined, options).format(value);
  }

  function createStarRatingElement(averageRating, ratingCount) {
    const container = document.createElement('div');
    container.className = 'star-rating';
    container.setAttribute('role', 'img');

    const hasRating = typeof averageRating === 'number' && Number.isFinite(averageRating);
    const countValue = Number.isFinite(Number(ratingCount)) ? Number(ratingCount) : 0;

    if (!hasRating || countValue <= 0) {
      const label = document.createElement('span');
      label.className = 'star-rating__no-rating';
      label.textContent = 'No rating';
      container.appendChild(label);
      container.setAttribute('aria-label', 'No rating yet');
      return container;
    }

    const normalized = Math.min(Math.max(averageRating, 0), 5);
    const rounded = Math.round(normalized * 10) / 10;

    const starsWrapper = document.createElement('span');
    starsWrapper.className = 'star-rating__stars';

    const baseStars = document.createElement('span');
    baseStars.className = 'star-rating__base';
    baseStars.textContent = '★★★★★';

    const fillStars = document.createElement('span');
    fillStars.className = 'star-rating__fill';
    fillStars.textContent = '★★★★★';
    fillStars.style.width = `${(normalized / 5) * 100}%`;

    starsWrapper.append(baseStars, fillStars);
    container.appendChild(starsWrapper);

    const label = document.createElement('span');
    label.className = 'star-rating__label';
    const ratingCountLabel = countValue === 1 ? '1 rating' : `${countValue} ratings`;
    label.textContent = `${rounded.toFixed(1)} · ${ratingCountLabel}`;
    container.appendChild(label);

    container.setAttribute('aria-label', `Rated ${rounded.toFixed(1)} out of 5 based on ${ratingCountLabel}`);

    return container;
  }

  function formatDate(dateString) {
    const date = new Date(dateString);
    if (Number.isNaN(date.getTime())) {
      return dateString;
    }
    return date.toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }

  function formatDateTime(dateString) {
    // Admin booking list: show date and hour only (no minutes)
    const date = new Date(dateString);
    if (Number.isNaN(date.getTime())) {
      return dateString;
    }
    return date.toLocaleString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
    });
  }

  function getVenueTitleValue(venue) {
    return venue && typeof venue.title === 'string' ? venue.title : '';
  }

  function getVenueFacilitiesText(venue) {
    if (!venue || !Array.isArray(venue.facilities) || !venue.facilities.length) {
      return '—';
    }
    return venue.facilities.join(', ');
  }

  function getVenueFacilitiesValue(venue) {
    if (!venue || !Array.isArray(venue.facilities) || !venue.facilities.length) {
      return '';
    }
    return venue.facilities.join(', ');
  }

  function getVenueAddonsText(venue) {
    if (!venue || !Array.isArray(venue.addons) || !venue.addons.length) {
      return '-';
    }
    const labels = venue.addons.map((addon) => (addon && addon.name ? String(addon.name).trim() : '')).filter((name) => name);
    return labels.length ? labels.join(', ') : '-';
  }

  function getVenueLocationValue(venue) {
    return venue && typeof venue.location === 'string' ? venue.location : '';
  }

  function getBookingGuestLabel(booking) {
    if (!booking) {
      return '-';
    }
    if (booking.guest_label) {
      return booking.guest_label;
    }
    if (booking.user) {
      const fullName = booking.user.full_name ? String(booking.user.full_name).trim() : '';
      const uname = booking.user.username ? String(booking.user.username).trim() : '';
      const email = booking.user.email ? String(booking.user.email).trim() : '';
      if (fullName) {
        const tag = uname || email;
        return tag ? `${fullName} (${tag})` : fullName;
      }
      if (uname) return uname;
      if (email) return email;
    }
    const fallback = booking.username || booking.email || booking.contact_phone;
    return fallback || '-';
  }

  function getBookingGuestValue(booking) {
    const label = getBookingGuestLabel(booking);
    return label === '-' ? '' : label;
  }

  function getBookingPhoneValue(booking) {
    if (!booking) {
      return '';
    }
    if (booking.contact_phone) {
      return String(booking.contact_phone).trim();
    }
    return '';
  }

  function getBookingPhoneLabel(value) {
    if (!value) {
      return '—';
    }
    const trimmed = String(value).trim();
    return trimmed || '—';
  }

  function getBookingVenueValue(booking) {
    if (booking && booking.venue && booking.venue.title) {
      return booking.venue.title;
    }
    return '';
  }

  function getBookingVenueLabel(booking) {
    const value = getBookingVenueValue(booking);
    return value || '—';
  }

  function getBookingDateLabel(booking) {
    const startRaw = booking && booking.start_date ? booking.start_date : '';
    const endRaw = booking && booking.end_date ? booking.end_date : '';
    const startFormatted = startRaw ? formatDateTime(startRaw) : '';
    const endFormatted = endRaw ? formatDateTime(endRaw) : '';
    const startLabel = startFormatted || startRaw || '—';
    const endLabel = endFormatted || endRaw || '—';
    return `${startLabel} – ${endLabel}`;
  }

  function getBookingCreatedValue(booking) {
    return booking && booking.created_at ? booking.created_at : '';
  }

  function getBookingCreatedLabel(booking) {
    const value = getBookingCreatedValue(booking);
    if (!value) return '—';
    const formatted = formatDateTime(value);
    return formatted || value;
  }

  function getBookingPaidLabel(booking) {
    return booking && booking.has_been_paid ? 'Paid' : 'Pending';
  }

  function getBookingNotesValue(booking) {
    return booking && booking.notes ? booking.notes : '';
  }

  function getBookingNotesLabel(booking) {
    const value = getBookingNotesValue(booking);
    return value || '—';
  }

  function getBookingAddonsLabel(booking) {
    if (!booking || !Array.isArray(booking.selected_addons) || !booking.selected_addons.length) {
      return '-';
    }

    const labels = booking.selected_addons

      .map((addon) => (addon && addon.name ? String(addon.name).trim() : ''))

      .filter((name) => name);

    return labels.length ? labels.join(', ') : '-';
  }

  function compareVenueRatings(a, b) {
    const averageA = Number(a && a.average_rating);
    const averageB = Number(b && b.average_rating);
    const safeAverageA = Number.isFinite(averageA) ? averageA : Number.NEGATIVE_INFINITY;
    const safeAverageB = Number.isFinite(averageB) ? averageB : Number.NEGATIVE_INFINITY;
    if (safeAverageA !== safeAverageB) {
      return safeAverageA - safeAverageB;
    }
    const countA = Number(a && a.rating_count);
    const countB = Number(b && b.rating_count);
    const safeCountA = Number.isFinite(countA) ? countA : 0;
    const safeCountB = Number.isFinite(countB) ? countB : 0;
    if (safeCountA !== safeCountB) {
      return safeCountA - safeCountB;
    }
    return 0;
  }

  function compareBookingDates(a, b) {
    const startA = Date.parse(a && a.start_date);
    const startB = Date.parse(b && b.start_date);
    const safeStartA = Number.isFinite(startA) ? startA : Number.NEGATIVE_INFINITY;
    const safeStartB = Number.isFinite(startB) ? startB : Number.NEGATIVE_INFINITY;
    if (safeStartA !== safeStartB) {
      return safeStartA - safeStartB;
    }
    const endA = Date.parse(a && a.end_date);
    const endB = Date.parse(b && b.end_date);
    const safeEndA = Number.isFinite(endA) ? endA : Number.NEGATIVE_INFINITY;
    const safeEndB = Number.isFinite(endB) ? endB : Number.NEGATIVE_INFINITY;
    if (safeEndA !== safeEndB) {
      return safeEndA - safeEndB;
    }
    return 0;
  }

  const collator = new Intl.Collator(undefined, { sensitivity: 'base', numeric: true });

  const tableSorters = {
    venues: {
      image: { type: 'number', getValue: (item) => (item && item.image_url ? 1 : 0) },
      title: { type: 'string', getValue: getVenueTitleValue },
      type: { type: 'string', getValue: (item) => (item && item.type ? item.type : '') },
      rating: { compare: compareVenueRatings },
      location: { type: 'string', getValue: getVenueLocationValue },
      facilities: { type: 'string', getValue: getVenueFacilitiesValue },
      price: { type: 'number', getValue: (item) => Number(item && item.price) },
      actions: { type: 'number', getValue: (item) => Number(item && item.id) },
    },
    bookings: {
      guest: { type: 'string', getValue: getBookingGuestValue },
      phone: { type: 'string', getValue: getBookingPhoneValue },
      venue: { type: 'string', getValue: getBookingVenueValue },
      dates: { compare: compareBookingDates },
      paid: { type: 'number', getValue: (item) => (item && item.has_been_paid ? 1 : 0) },
      notes: { type: 'string', getValue: getBookingNotesValue },
      created: { type: 'date', getValue: getBookingCreatedValue },
      actions: { type: 'number', getValue: (item) => Number(item && item.id) },
    },
  };

  function compareRecords(a, b, config) {
    if (!config) {
      return 0;
    }
    if (typeof config.compare === 'function') {
      const result = config.compare(a, b);
      if (result !== 0) {
        return result;
      }
      const idA = Number(a && a.id);
      const idB = Number(b && b.id);
      const safeIdA = Number.isFinite(idA) ? idA : 0;
      const safeIdB = Number.isFinite(idB) ? idB : 0;
      return safeIdA - safeIdB;
    }
    const type = config.type || 'string';
    const getter = typeof config.getValue === 'function' ? config.getValue : () => undefined;
    const valueA = getter(a);
    const valueB = getter(b);
    let result = 0;
    if (type === 'number') {
      const numA = Number(valueA);
      const numB = Number(valueB);
      const safeA = Number.isFinite(numA) ? numA : Number.NEGATIVE_INFINITY;
      const safeB = Number.isFinite(numB) ? numB : Number.NEGATIVE_INFINITY;
      result = safeA - safeB;
    } else if (type === 'date') {
      const timeA = Date.parse(valueA);
      const timeB = Date.parse(valueB);
      const safeA = Number.isFinite(timeA) ? timeA : Number.NEGATIVE_INFINITY;
      const safeB = Number.isFinite(timeB) ? timeB : Number.NEGATIVE_INFINITY;
      result = safeA - safeB;
    } else {
      const stringA = valueA === undefined || valueA === null ? '' : String(valueA);
      const stringB = valueB === undefined || valueB === null ? '' : String(valueB);
      result = collator.compare(stringA, stringB);
    }
    if (result !== 0) {
      return result;
    }
    const idA = Number(a && a.id);
    const idB = Number(b && b.id);
    const fallbackA = Number.isFinite(idA) ? idA : 0;
    const fallbackB = Number.isFinite(idB) ? idB : 0;
    return fallbackA - fallbackB;
  }

  function getFilteredRecords(section) {
    // Rely on the server to perform filtering (via the ``q`` parameter).
    // The in‑memory state for a section already contains only the rows
    // for the current page / query, so the "filtered" records are just
    // the current records.
    const records = Array.isArray(state[section]) ? state[section] : [];
    return records;
  }

  function getSortedRecords(section) {
    const records = getFilteredRecords(section).slice();
    const sortState = state.sort && state.sort[section];
    if (!sortState || !sortState.key) {
      return records;
    }
    const config = tableSorters[section] && tableSorters[section][sortState.key];
    if (!config) {
      return records;
    }
    records.sort((recordA, recordB) => {
      const comparison = compareRecords(recordA, recordB, config);
      if (comparison === 0) {
        return 0;
      }
      return sortState.direction === 'desc' ? -comparison : comparison;
    });
    return records;
  }

  function updateSortIndicators(section) {
    const headers = sortableHeaders[section] || [];
    const sortState = state.sort && state.sort[section];
    headers.forEach((header) => {
      const key = header.dataset.sortKey;
      const config = tableSorters[section] && tableSorters[section][key];
      if (!config) {
        header.classList.remove('is-sorted');
        header.setAttribute('aria-sort', 'none');
        return;
      }
      const isActive = sortState && sortState.key === key;
      header.classList.toggle('is-sorted', Boolean(isActive));
      if (isActive) {
        const direction = sortState.direction === 'desc' ? 'descending' : 'ascending';
        header.setAttribute('aria-sort', direction);
      } else {
        header.setAttribute('aria-sort', 'none');
      }
    });
  }

  function handleSortToggle(section, key) {
    const config = tableSorters[section] && tableSorters[section][key];
    if (!config) {
      return;
    }
    const current = state.sort && state.sort[section] ? state.sort[section] : { key: null, direction: 'asc' };
    let nextDirection = 'asc';
    if (current.key === key && current.direction === 'asc') {
      nextDirection = 'desc';
    } else if (current.key === key && current.direction === 'desc') {
      nextDirection = 'asc';
    }
    state.sort[section] = { key, direction: nextDirection };
    if (section === 'venues') {
      renderVenues();
    } else if (section === 'bookings') {
      renderBookings();
    }
  }

  function registerSorting() {
    Object.entries(sortableHeaders).forEach(([section, headers]) => {
      headers.forEach((header) => {
        const key = header.dataset.sortKey;
        if (!key) {
          return;
        }
        header.addEventListener('click', () => {
          handleSortToggle(section, key);
        });
        header.addEventListener('keydown', (event) => {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            handleSortToggle(section, key);
          }
        });
      });
      updateSortIndicators(section);
    });
  }

  function getPopularityColors(count) {
    const palette = ['#ea580c', '#f97316', '#fb923c', '#facc15', '#38d4c3', '#c084fc', '#f472b6', '#fb7185'];
    const colors = [];
    for (let index = 0; index < count; index += 1) {
      colors.push(palette[index % palette.length]);
    }
    return colors;
  }

  function computeNiceScale(values) {
    const dataPoints = Array.isArray(values) ? values.map((value) => Number(value)).filter((value) => Number.isFinite(value) && value >= 0) : [];

    if (dataPoints.length === 0) {
      return { suggestedMax: undefined, stepSize: undefined };
    }

    const maxValue = Math.max(...dataPoints);
    if (!(maxValue > 0)) {
      return { suggestedMax: undefined, stepSize: undefined };
    }

    const exponent = Math.floor(Math.log10(maxValue));
    const magnitude = 10 ** exponent;
    const normalized = maxValue / magnitude;
    let niceNormalized;

    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }

    const suggestedMax = niceNormalized * magnitude;
    const stepSize = suggestedMax / 5;

    return { suggestedMax, stepSize };
  }

  function createChartConfig(key, dataset) {
    if (key === 'sales') {
      const { suggestedMax, stepSize } = computeNiceScale(dataset.data);
      const yAxis = {
        beginAtZero: true,
        grace: '8%',
        grid: {
          color: 'rgba(15, 23, 42, 0.08)',
          drawBorder: false,
          borderDash: [4, 4],
        },
        ticks: {
          maxTicksLimit: 6,
          color: '#ffffff',
          callback(value) {
            return formatCurrency(value, { compact: true });
          },
        },
      };

      if (Number.isFinite(suggestedMax)) {
        yAxis.suggestedMax = suggestedMax;
      }
      if (Number.isFinite(stepSize) && stepSize > 0) {
        yAxis.ticks.stepSize = stepSize;
      }

      return {
        type: 'line',
        data: {
          labels: dataset.labels,
          datasets: [
            {
              label: 'Daily sales',
              data: dataset.data,
              borderColor: '#ea580c',
              backgroundColor: 'rgba(234, 88, 12, 0.18)',
              tension: 0.35,
              fill: true,
              pointRadius: 4,
              pointHoverRadius: 6,
              pointBorderWidth: 2,
              pointBackgroundColor: '#ffffff',
              pointBorderColor: '#ea580c',
              borderWidth: 2,
            },
          ],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          interaction: { intersect: false, mode: 'index' },
          layout: {
            padding: {
              top: 12,
              right: 16,
              bottom: 8,
              left: 8,
            },
          },
          scales: {
            x: {
              grid: {
                display: true,
                color: 'rgba(15, 23, 42, 0.04)',
                drawBorder: false,
              },
              ticks: {
                maxRotation: 0,
                autoSkip: true,
                maxTicksLimit: 6,
                color: '#ffffff',
                callback(value, index) {
                  const label = dataset.labels[index];
                  return formatDate(label);
                },
              },
            },
            y: yAxis,
          },
          plugins: {
            legend: { display: false },
            tooltip: {
              backgroundColor: 'rgba(2, 6, 23, 0.88)',
              borderColor: 'rgba(255, 255, 255, 0.14)',
              borderWidth: 1,
              titleColor: '#ffffff',
              bodyColor: '#ffffff',
              callbacks: {
                title(context) {
                  if (!context.length) {
                    return '';
                  }
                  return formatDate(context[0].label);
                },
                label(context) {
                  const amount = context.parsed.y ?? context.parsed ?? 0;
                  return formatCurrency(amount);
                },
              },
            },
          },
        },
      };
    }

    return {
      type: 'doughnut',
      data: {
        labels: dataset.labels,
        datasets: [
          {
            data: dataset.data,
            backgroundColor: getPopularityColors(dataset.labels.length),
            borderWidth: 0,
            hoverOffset: 12,
            borderRadius: 10,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '58%',
        layout: {
          padding: {
            top: 12,
            bottom: 12,
            left: 12,
            right: 12,
          },
        },
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              boxWidth: 14,
              usePointStyle: true,
              pointStyle: 'circle',
              padding: 16,
              color: '#ffffff',
            },
          },
          tooltip: {
            backgroundColor: 'rgba(2, 6, 23, 0.88)',
            borderColor: 'rgba(255, 255, 255, 0.14)',
            borderWidth: 1,
            titleColor: '#ffffff',
            bodyColor: '#ffffff',
            callbacks: {
              label(context) {
                const value = Number.isFinite(context.parsed) ? context.parsed : 0;
                const suffix = value === 1 ? 'booking' : 'bookings';
                const label = context.label || '';
                const datasetValues =
                  context && context.chart && context.chart.data && Array.isArray(context.chart.data.datasets)
                    ? context.chart.data.datasets[context.datasetIndex]?.data || []
                    : [];
                const total = Array.isArray(datasetValues) ? datasetValues.reduce((sum, item) => sum + (Number(item) || 0), 0) : 0;
                const percentage = total > 0 ? (value / total) * 100 : 0;
                let percentageLabel = '';
                if (Number.isFinite(percentage) && total > 0) {
                  const precision = percentage >= 10 ? 0 : 1;
                  percentageLabel = ` (${percentage.toFixed(precision)}%)`;
                }
                return `${label}: ${value} ${suffix}${percentageLabel}`;
              },
            },
          },
        },
      },
    };
  }

  function renderChart(key) {
    const element = chartElements[key];
    if (!element || !element.canvas) {
      return;
    }
    const dataset = analyticsData[key] || { labels: [], data: [] };
    const hasData =
      Array.isArray(dataset.labels) && dataset.labels.length > 0 && Array.isArray(dataset.data) && dataset.data.some((value) => Number(value) > 0);

    if (!hasData) {
      if (chartInstances[key]) {
        chartInstances[key].destroy();
        chartInstances[key] = null;
      }
      if (element.canvas) {
        element.canvas.classList.add('is-hidden');
      }
      if (element.empty) {
        element.empty.classList.remove('is-hidden');
      }
      return;
    }

    if (element.canvas) {
      element.canvas.classList.remove('is-hidden');
    }
    if (element.empty) {
      element.empty.classList.add('is-hidden');
    }

    if (typeof Chart === 'undefined') {
      return;
    }

    if (!chartInstances[key]) {
      chartInstances[key] = new Chart(element.canvas, createChartConfig(key, dataset));
      return;
    }

    const chart = chartInstances[key];
    chart.data.labels = dataset.labels.slice();
    chart.data.datasets[0].data = dataset.data.slice();
    if (key === 'popularity') {
      chart.data.datasets[0].backgroundColor = getPopularityColors(dataset.labels.length);
    }
    chart.update();
  }

  function setChartData(key, raw) {
    analyticsData[key] = normalizeSeries(raw);
    renderChart(key);
  }

  function updateAnalytics(meta) {
    if (!meta || typeof meta !== 'object') {
      return;
    }
    if (Object.prototype.hasOwnProperty.call(meta, 'sales')) {
      setChartData('sales', meta.sales);
    }
    if (Object.prototype.hasOwnProperty.call(meta, 'popularity')) {
      setChartData('popularity', meta.popularity);
    }
  }

  function initializeCharts() {
    renderChart('sales');
    renderChart('popularity');
  }

  function showToast(message) {
    if (!toast) {
      return;
    }
    toast.textContent = message;
    toast.classList.add('is-visible');
    window.clearTimeout(showToast.timeoutId);
    showToast.timeoutId = window.setTimeout(() => {
      toast.classList.remove('is-visible');
    }, 2600);
  }

  function toggleEmptyState(section) {
    const emptyState = emptyStates[section];
    if (!emptyState) {
      return;
    }
    const items = state[section] || [];
    const meta = state.pagination[section] || {};
    const hasItems = Array.isArray(items) && items.length > 0;
    const query = (typeof meta.query === 'string' ? meta.query : state.search[section]) || '';
    const defaultMessage = emptyState.dataset.emptyDefault || emptyState.textContent;
    const filteredMessage = emptyState.dataset.emptyFiltered || defaultMessage;
    emptyState.textContent = query ? filteredMessage : defaultMessage;
    emptyState.classList.toggle('is-visible', !hasItems);
  }

  function setLoading(section, isLoading) {
    const wrapper = tableWrappers[section];
    if (!wrapper) {
      return;
    }
    const active = Boolean(isLoading);
    wrapper.classList.toggle('is-loading', active);
    wrapper.setAttribute('aria-busy', active ? 'true' : 'false');
  }

  function computePageList(current, total, maxLength = 5) {
    const safeTotal = Math.max(1, total || 1);
    const safeCurrent = Math.min(Math.max(1, current || 1), safeTotal);
    const visible = Math.max(1, maxLength || 1);
    let start = Math.max(1, safeCurrent - Math.floor(visible / 2));
    let end = start + visible - 1;
    if (end > safeTotal) {
      end = safeTotal;
      start = Math.max(1, end - visible + 1);
    }
    const pages = [];
    for (let page = start; page <= end; page += 1) {
      pages.push(page);
    }
    return pages;
  }

  function handlePageChange(section, page) {
      const meta = state.pagination[section] || {};
      const parsed = Number(page);
      const pageNumber = Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
      const pageSize = meta.pageSize || DEFAULT_PAGE_SIZE;
      const query = state.search[section] || '';
      loadSection(section, { page: pageNumber, pageSize, query });
  }

  function createPaginationButton(label, pageNumber, section, options = {}) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = label;
    if (options.ariaLabel) {
      button.setAttribute('aria-label', options.ariaLabel);
    }
    if (options.disabled) {
      button.disabled = true;
      return button;
    }
    button.dataset.page = String(pageNumber);
    button.addEventListener('click', () => {
      handlePageChange(section, pageNumber);
    });
    return button;
  }

  function renderPagination(section) {
    const container = paginationContainers[section];
    if (!container) {
      return;
    }
    const meta = state.pagination[section];
    container.innerHTML = '';

    if (!meta || meta.totalPages <= 1) {
      container.classList.add('is-hidden');
      return;
    }
    container.classList.remove('is-hidden');
    const fragment = document.createDocumentFragment();
    fragment.appendChild(
      createPaginationButton('Prev', meta.page - 1, section, {
        disabled: !meta.hasPrevious,
        ariaLabel: 'Previous page',
      })
    );
    const pages = computePageList(meta.page, meta.totalPages);
    pages.forEach((pageNumber) => {
      const button = createPaginationButton(String(pageNumber), pageNumber, section);
      if (pageNumber === meta.page) {
        button.classList.add('is-active');
        button.disabled = true;
        button.setAttribute('aria-current', 'page');
      }
      fragment.appendChild(button);
    });
    fragment.appendChild(
      createPaginationButton('Next', meta.page + 1, section, {
        disabled: !meta.hasNext,
        ariaLabel: 'Next page',
      })
    );
    container.appendChild(fragment);
  }

  function updateSummary(section) {
    const summary = tableSummaries[section];
    if (!summary) {
      return;
    }
    const meta = state.pagination[section];
    const items = state[section];
    if (!meta || !items || !items.length || !meta.totalItems) {
      summary.textContent = '';
      return;
    }
    const startIndex = (meta.page - 1) * meta.pageSize + 1;
    const endIndex = Math.min(meta.totalItems, startIndex + items.length - 1);
    const queryText = meta.query ? ` matching “${meta.query}”` : '';
    summary.textContent = `Showing ${startIndex}–${endIndex} of ${meta.totalItems}${queryText} results.`;
  }

  function updateTableFooter(section) {
    const footer = tableFooters[section];
    if (!footer) {
      return;
    }
    const items = getFilteredRecords(section);
    const hasItems = Array.isArray(items) && items.length > 0;
    footer.classList.toggle('is-hidden', !hasItems);
  }

    function handleSearchChangeLocal(section, rawValue) {
      if (!(section in searchTimeouts)) {
        return;
      }
    const query = typeof rawValue === 'string' ? rawValue.trim() : '';
    state.search[section] = query;
    const meta = state.pagination[section] || {};
    const pageSize = meta.pageSize || DEFAULT_PAGE_SIZE;
    window.clearTimeout(searchTimeouts[section]);
    searchTimeouts[section] = window.setTimeout(() => {
      loadSection(section, { page: 1, pageSize, query });
    }, 220);
  }

  // Client-side search overrides: once the initial data page is loaded,
  // filter the in-memory records instead of issuing a new request on
  // every keystroke from the admin search boxes.
  function hasActiveSearch(section) {
    const raw =
      state.search && typeof state.search[section] === 'string' ? state.search[section] : '';
    return raw.trim().length > 0;
  }

  function toggleEmptyState(section) {
    const emptyState = emptyStates[section];
    if (!emptyState) {
      return;
    }
    const items = getFilteredRecords(section);
    const rawQuery =
      state.search && typeof state.search[section] === 'string' ? state.search[section] : '';
    const query = rawQuery.trim();
    const hasItems = Array.isArray(items) && items.length > 0;
    const defaultMessage = emptyState.dataset.emptyDefault || emptyState.textContent;
    const filteredMessage = emptyState.dataset.emptyFiltered || defaultMessage;
    emptyState.textContent = query ? filteredMessage : defaultMessage;
    emptyState.classList.toggle('is-visible', !hasItems);
  }

  function updateSummary(section) {
    const summary = tableSummaries[section];
    if (!summary) {
      return;
    }
    const meta = state.pagination[section];
    const items = getFilteredRecords(section);
    const rawQuery =
      state.search && typeof state.search[section] === 'string' ? state.search[section] : '';
    const query = rawQuery.trim();

    if (!items || !items.length) {
      summary.textContent = '';
      return;
    }

    if (!meta || !meta.totalItems || !meta.pageSize) {
      if (query) {
        summary.textContent = `Showing ${items.length} result(s) matching "${query}".`;
      } else {
        summary.textContent = `Showing ${items.length} result(s).`;
      }
      return;
    }

    const startIndex = (meta.page - 1) * meta.pageSize + 1;
    const endIndex = Math.min(meta.totalItems, startIndex + items.length - 1);
    const queryText =
      query || meta.query ? ` matching "${query || meta.query}"` : '';
    summary.textContent = `Showing ${startIndex}–${endIndex} of ${meta.totalItems}${queryText} results.`;
  }

  function handleSearchChange(section, rawValue) {
    if (!(section in searchTimeouts)) {
      return;
    }
    const query = typeof rawValue === 'string' ? rawValue.trim() : '';
    state.search[section] = query;
    const meta = state.pagination[section] || {};
    const pageSize = meta.pageSize || DEFAULT_PAGE_SIZE;
    window.clearTimeout(searchTimeouts[section]);
    searchTimeouts[section] = window.setTimeout(() => {
      loadSection(section, { page: 1, pageSize, query });
    }, 220);
  }

  // Final summary helper: uses server pagination metadata so that the
  // "Showing X‑Y of Z" text always reflects the current query.
  function updateSummary(section) {
    const summary = tableSummaries[section];
    if (!summary) {
      return;
    }

    const meta = state.pagination[section];
    const items = getFilteredRecords(section);
    const rawQuery =
      state.search && typeof state.search[section] === 'string' ? state.search[section] : '';
    const query = rawQuery.trim();

    if (!items || !items.length) {
      summary.textContent = '';
      return;
    }

    if (!meta || !meta.totalItems || !meta.pageSize) {
      if (query) {
        summary.textContent = `Showing ${items.length} result(s) matching "${query}".`;
      } else {
        summary.textContent = `Showing ${items.length} result(s).`;
      }
      return;
    }

    const totalItems = meta.totalItems;
    const startIndex = (meta.page - 1) * meta.pageSize + 1;
    const endIndex = Math.min(totalItems, startIndex + items.length - 1);
    const queryText = query || meta.query ? ` matching "${query || meta.query}"` : '';
    summary.textContent = `Showing ${startIndex}-${endIndex} of ${totalItems}${queryText} results.`;
  }

  function createAutocompleteController(fieldElement, options = {}) {
    if (!fieldElement) {
      return null;
    }

    const textInput = fieldElement.querySelector('input[type="text"]');
    const hiddenInput = fieldElement.querySelector('input[type="hidden"]');
    const panel = fieldElement.querySelector('[data-autocomplete-panel]');

    if (!textInput || !panel) {
      return null;
    }

    const settings = {
