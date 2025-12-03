      minChars: 1,
      debounce: 200,
      ...options,
    };

    let items = [];
    let highlightedIndex = -1;
    let debounceId = null;
    let lastRequestId = 0;

    function setHighlightedIndex(index) {
      highlightedIndex = index;
      const optionsNodes = panel.querySelectorAll('.autocomplete-option');
      optionsNodes.forEach((option, optionIndex) => {
        option.classList.toggle('is-active', optionIndex === highlightedIndex);
        if (optionIndex === highlightedIndex) {
          option.scrollIntoView({ block: 'nearest' });
        }
      });
    }

    function close() {
      panel.hidden = true;
      panel.innerHTML = '';
      items = [];
      highlightedIndex = -1;
      lastRequestId += 1;
      if (typeof settings.onClose === 'function') {
        settings.onClose();
      }
    }

    function setSelection(displayValue = '', hiddenValue = '') {
      textInput.value = displayValue;
      if (hiddenInput) {
        hiddenInput.value = hiddenValue;
      }
    }

    function renderOptions(list) {
      panel.innerHTML = '';

      if (!list.length) {
        const empty = document.createElement('div');
        empty.className = 'autocomplete-empty';
        empty.textContent = typeof settings.emptyMessage === 'function' ? settings.emptyMessage() : settings.emptyMessage || 'No results found.';
        panel.appendChild(empty);
        panel.hidden = false;
        return;
      }

      const fragment = document.createDocumentFragment();
      list.forEach((item, index) => {
        const option = document.createElement('div');
        option.className = 'autocomplete-option';
        option.dataset.index = index.toString();

        const primary = document.createElement('strong');
        const primaryText = settings.getPrimaryText ? settings.getPrimaryText(item) : '';
        primary.textContent = primaryText || '';
        option.appendChild(primary);

        const secondaryText = settings.getSecondaryText ? settings.getSecondaryText(item) : '';
        if (secondaryText) {
          const secondary = document.createElement('span');
          secondary.textContent = secondaryText;
          option.appendChild(secondary);
        }

        option.addEventListener('mousedown', (event) => {
          event.preventDefault();
          select(index);
        });

        fragment.appendChild(option);
      });

      panel.appendChild(fragment);
      panel.hidden = false;
      setHighlightedIndex(-1);
    }

    function select(index) {
      const item = items[index];
      if (!item) {
        return;
      }
      const display = settings.getInputValue ? settings.getInputValue(item) : '';
      const value = settings.getHiddenValue ? settings.getHiddenValue(item) : '';
      setSelection(display, value);
      if (typeof settings.onSelect === 'function') {
        settings.onSelect(item);
      }
      close();
    }

    async function requestItems(query) {
      if (typeof settings.fetchItems !== 'function') {
        return;
      }

      const requestId = ++lastRequestId;

      try {
        const result = await settings.fetchItems(query);
        if (requestId !== lastRequestId) {
          return;
        }
        items = Array.isArray(result) ? result : [];
        renderOptions(items);
      } catch (error) {
        if (error && error.name === 'AbortError') {
          return;
        }
        console.error(error);
        close();
      }
    }

    function handleInput(event) {
      if (hiddenInput) {
        hiddenInput.value = '';
      }
      const query = event.target.value.trim();
      window.clearTimeout(debounceId);
      if (!query || query.length < settings.minChars) {
        close();
        return;
      }
      debounceId = window.setTimeout(() => {
        requestItems(query);
      }, settings.debounce);
    }

    function handleKeydown(event) {
      if (!items.length) {
        if (event.key === 'Escape') {
          close();
        }
        return;
      }
      if (event.key === 'ArrowDown') {
        event.preventDefault();
        const nextIndex = highlightedIndex + 1 >= items.length ? 0 : highlightedIndex + 1;
        setHighlightedIndex(nextIndex);
      } else if (event.key === 'ArrowUp') {
        event.preventDefault();
        const nextIndex = highlightedIndex <= 0 ? items.length - 1 : highlightedIndex - 1;
        setHighlightedIndex(nextIndex);
      } else if (event.key === 'Enter') {
        if (highlightedIndex >= 0) {
          event.preventDefault();
          select(highlightedIndex);
        }
      } else if (event.key === 'Escape') {
        close();
      }
    }

    textInput.addEventListener('input', handleInput);
    textInput.addEventListener('keydown', handleKeydown);
    textInput.addEventListener('focus', () => {
      const query = textInput.value.trim();
      if (query.length >= settings.minChars) {
        requestItems(query);
      }
    });
    textInput.addEventListener('blur', () => {
      window.setTimeout(() => {
        close();
      }, 120);
    });

    return {
      input: textInput,
      hiddenInput,
      close,
      clear() {
        setSelection('', '');
        close();
      },
      setSelection,
      refresh() {
        const query = textInput.value.trim();
        if (query.length >= settings.minChars) {
          requestItems(query);
        }
      },
    };
  }

  function closeAllAutocompletes() {
    Object.values(autocompleteControllers).forEach((controller) => {
      if (controller) {
        controller.close();
      }
    });
  }

  function clearAutocompletes() {
    Object.values(autocompleteControllers).forEach((controller) => {
      if (controller) {
        controller.clear();
      }
    });
  }

  function syncVenueAutocompleteSelection() {
    const venueController = autocompleteControllers.venue;
    if (!venueController || !venueController.hiddenInput) {
      return;
    }
    const currentValue = venueController.hiddenInput.value;
    if (!currentValue) {
      return;
    }
    const matchingVenue = state.venues.find((venue) => Number(venue.id) === Number(currentValue));
    if (matchingVenue) {
      venueController.setSelection(matchingVenue.title || '', matchingVenue.id);
      return;
    }
    const venuesMeta = state.pagination.venues || {};
    const totalVenues =
      typeof venuesMeta.total_available === 'number'
        ? venuesMeta.total_available
        : typeof venuesMeta.totalItems === 'number'
        ? venuesMeta.totalItems
        : state.venues.length;
    if (totalVenues === 0) {
      venueController.setSelection('', '');
    }
  }

  const userAutocompleteField = entityForm.querySelector('[data-autocomplete="user"]');
  if (userAutocompleteField) {
    autocompleteControllers.user = createAutocompleteController(userAutocompleteField, {
      minChars: 2,
      debounce: 220,
      fetchItems: async (query) => {
        if (!endpoints.users || !endpoints.users.search) {
          return [];
        }
        if (userSearchController) {
          userSearchController.abort();
        }
        userSearchController = new AbortController();
        try {
          const response = await fetch(`${endpoints.users.search}?q=${encodeURIComponent(query)}`, {
            headers: { 'X-Requested-With': 'XMLHttpRequest' },
            signal: userSearchController.signal,
          });
          if (!response.ok) {
            throw new Error('Search failed');
          }
          const payload = await response.json();
          if (payload.meta && typeof payload.meta.has_users === 'boolean') {
            state.hasUsers = payload.meta.has_users;
            updateActionButton();
          }
          if (!payload.success) {
            return [];
          }
          return Array.isArray(payload.data) ? payload.data : [];
        } finally {
          userSearchController = null;
        }
      },
      getPrimaryText: (item) => (item.full_name ? item.full_name : item.username),
      getSecondaryText: (item) => {
        if (item.full_name) {
          return item.username;
        }
        return item.email || '';
      },
      getInputValue: (item) => item.username || '',
      getHiddenValue: (item) => (item.id !== undefined ? item.id : ''),
      emptyMessage: () => (state.hasUsers ? 'No users found.' : 'No users available yet.'),
      onSelect: () => {
        state.hasUsers = true;
        updateActionButton();
      },
      onClose: () => {
        if (userSearchController) {
          userSearchController.abort();
          userSearchController = null;
        }
      },
    });
  }

  const venueAutocompleteField = entityForm.querySelector('[data-autocomplete="venue"]');
  if (venueAutocompleteField) {
    autocompleteControllers.venue = createAutocompleteController(venueAutocompleteField, {
      minChars: 1,
      debounce: 160,
      fetchItems: async (query) => {
        const normalized = query.trim().toLowerCase();
        if (!normalized) {
          return [];
        }
        const matches = state.venues.filter((venue) => {
          const title = venue.title ? venue.title.toLowerCase() : '';
          const location = venue.location ? venue.location.toLowerCase() : '';
          return title.includes(normalized) || location.includes(normalized);
        });
        return matches.slice(0, 8);
      },
      getPrimaryText: (item) => item.title || '',
      getSecondaryText: (item) => item.location || '',
      getInputValue: (item) => item.title || '',
      getHiddenValue: (item) => (item.id !== undefined ? item.id : ''),
      emptyMessage: () => (state.venues.length ? 'No venues found.' : 'Create a venue first.'),
      onSelect: (item) => {
        if (!entityForm || entityForm.dataset.section !== 'bookings') {
          return;
        }
        const venueId =
          item && item.id !== undefined ? item.id : getCurrentVenueId();
        const bookingAddonsField = entityForm.querySelector('[data-addons-input]');
        if (bookingAddonsField) {
          bookingAddonsField.value = '[]';
        }
        hydrateAddonsField([]);
        const available = getCurrentVenueAddons();
        setBookingAddonsAvailability(available.length > 0, venueId);
      },
    });

    const venueTextInput = venueAutocompleteField.querySelector('input[type="text"]');
    if (venueTextInput) {
      venueTextInput.addEventListener('input', () => {
        if (!entityForm || entityForm.dataset.section !== 'bookings') {
          return;
        }
        if (!venueTextInput.value.trim()) {
          const bookingAddonsField = entityForm.querySelector('[data-addons-input]');
          if (bookingAddonsField) {
            bookingAddonsField.value = '[]';
          }
          hydrateAddonsField([]);
          setBookingAddonsAvailability(false, null);
        }
      });
    }
  }

  function renderVenues() {
    venuesTableBody.innerHTML = '';
    const fragment = document.createDocumentFragment();
    const records = getSortedRecords('venues');
    records.forEach((venue) => {
      const row = document.createElement('tr');
      row.dataset.recordId = venue.id;

      const imageCell = document.createElement('td');
      if (venue.image_url) {
        const img = document.createElement('img');
        img.src = venue.image_url;
        img.alt = `${venue.title} preview`;
        imageCell.appendChild(img);
      } else {
        const placeholder = document.createElement('span');
        placeholder.className = 'image-placeholder';
        placeholder.textContent = 'No image';
        imageCell.appendChild(placeholder);
      }
      row.appendChild(imageCell);

      const titleCell = document.createElement('td');
      titleCell.textContent = getVenueTitleValue(venue) || '—';
      row.appendChild(titleCell);

      const descriptionCell = document.createElement('td');
      descriptionCell.dataset.col = 'venue-description';
      const descriptionText =
        typeof venue.description === 'string' && venue.description.trim() ? venue.description.trim() : '—';
      const descSpan = document.createElement('span');
      descSpan.className = 'venue-description__text';
      descSpan.textContent = descriptionText;
      descriptionCell.appendChild(descSpan);
      row.appendChild(descriptionCell);

      const typeCell = document.createElement('td');
      typeCell.textContent = venue.type || '—';
      row.appendChild(typeCell);

      const ratingCell = document.createElement('td');
      const ratingElement = createStarRatingElement(venue.average_rating, venue.rating_count);
      ratingCell.appendChild(ratingElement);
      row.appendChild(ratingCell);

      const locationCell = document.createElement('td');
      const locationValue = getVenueLocationValue(venue);
      locationCell.textContent = locationValue || '—';
      row.appendChild(locationCell);

      const facilitiesCell = document.createElement('td');
      facilitiesCell.textContent = getVenueFacilitiesText(venue);
      row.appendChild(facilitiesCell);

      const addonsCell = document.createElement('td');
      addonsCell.textContent = getVenueAddonsText(venue);
      row.appendChild(addonsCell);

      const priceCell = document.createElement('td');
      priceCell.textContent = formatCurrency(venue.price);
      row.appendChild(priceCell);

      const actionsCell = document.createElement('td');
      actionsCell.className = 'actions-col';
      const actionGroup = document.createElement('div');
      actionGroup.className = 'table-actions';

      const editButton = document.createElement('button');
      editButton.type = 'button';
      editButton.dataset.action = 'edit';
      editButton.dataset.id = venue.id;
      editButton.textContent = 'Edit';

      const deleteButton = document.createElement('button');
      deleteButton.type = 'button';
      deleteButton.dataset.action = 'delete';
      deleteButton.dataset.id = venue.id;
      deleteButton.textContent = 'Delete';

      actionGroup.append(editButton, deleteButton);
      actionsCell.appendChild(actionGroup);
      row.appendChild(actionsCell);

      fragment.appendChild(row);
    });

    venuesTableBody.appendChild(fragment);
    toggleEmptyState('venues');
    updateSummary('venues');
    renderPagination('venues');
    updateTableFooter('venues');
    animateTableRows(venuesTableBody);
    updateSortIndicators('venues');
  }

  function renderBookings() {
    bookingsTableBody.innerHTML = '';
    const fragment = document.createDocumentFragment();
    const records = getSortedRecords('bookings');

    records.forEach((booking) => {
      const row = document.createElement('tr');
      row.dataset.recordId = booking.id;

      const guestCell = document.createElement('td');
      guestCell.textContent = getBookingGuestLabel(booking);
      row.appendChild(guestCell);

      const phoneCell = document.createElement('td');
      phoneCell.textContent = getBookingPhoneLabel(booking.contact_phone);
      row.appendChild(phoneCell);

      const venueCell = document.createElement('td');
      venueCell.textContent = getBookingVenueLabel(booking);
      row.appendChild(venueCell);

      const datesCell = document.createElement('td');
      datesCell.textContent = getBookingDateLabel(booking);
      row.appendChild(datesCell);

      const createdCell = document.createElement('td');
      createdCell.textContent = getBookingCreatedLabel(booking);
      row.appendChild(createdCell);

      const paidCell = document.createElement('td');
      paidCell.textContent = getBookingPaidLabel(booking);
      row.appendChild(paidCell);

      const notesCell = document.createElement('td');
      notesCell.textContent = getBookingNotesLabel(booking);
      row.appendChild(notesCell);

      const addonsCell = document.createElement('td');
      addonsCell.textContent = getBookingAddonsLabel(booking);
      row.appendChild(addonsCell);

      const actionsCell = document.createElement('td');
      actionsCell.className = 'actions-col';
      const actionGroup = document.createElement('div');
      actionGroup.className = 'table-actions';

      const editButton = document.createElement('button');
      editButton.type = 'button';
      editButton.dataset.action = 'edit';
      editButton.dataset.id = booking.id;
      editButton.textContent = 'Edit';

      const deleteButton = document.createElement('button');
      deleteButton.type = 'button';
      deleteButton.dataset.action = 'delete';
      deleteButton.dataset.id = booking.id;
      deleteButton.textContent = 'Delete';

      actionGroup.append(editButton, deleteButton);
      actionsCell.appendChild(actionGroup);
      row.appendChild(actionsCell);

      fragment.appendChild(row);
    });

    bookingsTableBody.appendChild(fragment);
    toggleEmptyState('bookings');
    updateSummary('bookings');
    renderPagination('bookings');
    updateTableFooter('bookings');
    animateTableRows(bookingsTableBody);
    updateSortIndicators('bookings');
  }

  function updateHeader(section) {
    const config = sectionConfig[section];
    if (!config) {
      return;
    }
    sectionTitle.textContent = config.title;
    sectionDescription.textContent = config.description;
    actionButton.querySelector('.btn-label').textContent = config.buttonLabel;
  }

  function updateActionButton() {
    if (state.currentSection === 'bookings') {
      const venuesMeta = state.pagination.venues || {};
      const totalVenues =
        typeof venuesMeta.total_available === 'number'
          ? venuesMeta.total_available
          : typeof venuesMeta.totalItems === 'number'
          ? venuesMeta.totalItems
          : state.venues.length;
      const hasVenues = totalVenues > 0;
      const hasUsers = state.hasUsers;
      const canCreate = hasVenues && hasUsers;
      actionButton.disabled = !canCreate;
      if (!canCreate) {
        const missing = [];
        if (!hasVenues) {
          missing.push('a venue');
        }
        if (!hasUsers) {
          missing.push('a user');
        }
        actionButton.title = `Create ${missing.join(' and ')} before adding bookings.`;
      } else {
        actionButton.title = '';
      }
    } else {
      actionButton.disabled = false;
      actionButton.title = '';
    }
  }

  function setSidebarCollapsed(collapsed) {
    app.classList.toggle('sidebar-collapsed', collapsed);
    if (sidebarToggle) {
      sidebarToggle.setAttribute('aria-pressed', String(collapsed));
      sidebarToggle.setAttribute('aria-label', collapsed ? 'Expand sidebar' : 'Collapse sidebar');
      sidebarToggle.textContent = collapsed ? '→' : '←';
    }
  }

  function setActiveSection(section) {
    if (!sectionConfig[section]) {
      return;
    }
    state.currentSection = section;

    let activeButton = null;
    navButtons.forEach((button) => {
      const isActive = button.dataset.target === section;
      button.classList.toggle('is-active', isActive);
      if (isActive) {
        activeButton = button;
      }
    });

    let activeSectionElement = null;
    contentSections.forEach((contentSection) => {
      const isActive = contentSection.dataset.section === section;
      contentSection.classList.toggle('is-hidden', !isActive);
      if (isActive) {
        activeSectionElement = contentSection;
      }
    });

    animateActiveNavButton(activeButton);
    animateSectionEntry(activeSectionElement);

    if (searchInputs[section]) {
      searchInputs[section].value = state.search[section] || '';
    }

    updateHeader(section);
    updateActionButton();
    refreshFromServer(section);
  }
