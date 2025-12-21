
  function registerSidebarToggle() {
    if (!sidebarToggle) {
      return;
    }
    const stored = localStorage.getItem(sidebarToggleKey);
    const initialCollapsed = stored === 'true';
    setSidebarCollapsed(initialCollapsed);
    sidebarToggle.addEventListener('click', () => {
      const next = !app.classList.contains('sidebar-collapsed');
      setSidebarCollapsed(next);
      localStorage.setItem(sidebarToggleKey, String(next));
      sidebarToggle.classList.add('is-animating');
      sidebarToggle.addEventListener(
        'animationend',
        () => {
          sidebarToggle.classList.remove('is-animating');
        },
        { once: true },
      );
    });
  }

  function clearForm() {
    entityForm.reset();
    hydrateAddonsField([]);
    if (entityForm.dataset.section === 'bookings') {
      setBookingAddonsAvailability(false, null);
    }
    clearAutocompletes();
    if (entityForm.dataset.section === 'bookings') {
      const paidField = entityForm.querySelector('input[name="has_been_paid"]');
      if (paidField) {
        paidField.checked = false;
      }
    }
  }

  function clearErrors() {
    if (modalErrors) {
      modalErrors.hidden = true;
      modalErrors.innerHTML = '';
    }
  }

  function showErrors(messages) {
    if (!modalErrors) {
      return;
    }
    if (!messages || !messages.length) {
      clearErrors();
      return;
    }
    modalErrors.innerHTML = `<ul>${messages.map((msg) => `<li>${msg}</li>`).join('')}</ul>`;
    modalErrors.hidden = false;
  }

  function openModal(mode, section, recordId) {
    if (section === 'bookings' && mode === 'create') {
      if (!state.hasUsers) {
        showToast('Create a user before adding bookings.');
        return;
      }
      if (!state.venues.length) {
        showToast('Create a venue before adding bookings.');
        return;
      }
    }

    state.modalMode = mode;
    state.editingId = recordId || null;
    entityForm.dataset.mode = mode;
    entityForm.dataset.section = section;
    entityForm.dataset.recordId = recordId || '';

    setActiveFormSection(section);

    clearForm();
    clearErrors();
    closeAllAutocompletes();

    let editingVenue = null;
    if (section === 'venues' && recordId) {
      editingVenue =
        state.venues.find((item) => Number(item.id) === Number(recordId)) || null;
    }
    if (section === 'venues') {
      const addons =
        editingVenue && Array.isArray(editingVenue.addons) ? editingVenue.addons : [];
      hydrateAddonsField(addons);
    } else {
      hydrateAddonsField([]);
      setBookingAddonsAvailability(false, null);
    }

    if (mode === 'edit' && recordId) {
      if (section === 'venues') {
        if (editingVenue) {
          entityForm.querySelector('input[name="title"]').value = editingVenue.title;
          const typeField = entityForm.querySelector('select[name="type"]');
          if (typeField) {
            const fallback = typeField.options.length ? typeField.options[0].value : '';
            typeField.value = editingVenue.type || fallback;
          }
          entityForm.querySelector('textarea[name="description"]').value = editingVenue.description || '';
          entityForm.querySelector('input[name="facilities"]').value = (editingVenue.facilities || []).join(', ');
          entityForm.querySelector('input[name="price"]').value = editingVenue.price;
          entityForm.querySelector('input[name="location"]').value = editingVenue.location || '';
          const imageField = entityForm.querySelector('input[name="image"]');
          if (imageField) {
            imageField.value = '';
          }
        }
      } else if (section === 'bookings') {
        const booking =
          state.bookings.find((item) => Number(item.id) === Number(recordId)) || null;
        if (booking) {
          if (autocompleteControllers.user) {
            const usernameValue = booking.user ? booking.user.username : booking.username || '';
            const userIdValue = booking.user ? booking.user.id : '';
            autocompleteControllers.user.setSelection(usernameValue, userIdValue);
          }
          if (autocompleteControllers.venue) {
            const venueTitle = booking.venue ? booking.venue.title : '';
            const venueId = booking.venue ? booking.venue.id : '';
            autocompleteControllers.venue.setSelection(venueTitle, venueId);
            setCurrentVenuePrice(
              booking.venue && booking.venue.price !== undefined
                ? Number(booking.venue.price)
                : null
            );
          }
          const startInput = entityForm.querySelector('input[name="start_date"]');
          if (startInput) {
            startInput.value = formatDateTimeLocal(booking.start_date);
          }
          const endInput = entityForm.querySelector('input[name="end_date"]');
          if (endInput) {
            endInput.value = formatDateTimeLocal(booking.end_date);
          }
          entityForm.querySelector('input[name="has_been_paid"]').checked =
            Boolean(booking.has_been_paid);
          entityForm.querySelector('textarea[name="notes"]').value = booking.notes || '';
          const bookingAddonsField = entityForm.querySelector('[data-addons-input]');
          if (bookingAddonsField) {
            bookingAddonsField.value = JSON.stringify(booking.selected_addons || []);
          }
          const availableAddons = getCurrentVenueAddons();
          const venueId = booking.venue ? booking.venue.id : null;
          setBookingAddonsAvailability(availableAddons.length > 0, venueId);
          hydrateAddonsField(booking.selected_addons || []);
        }
      }
    } else if (section === 'bookings') {
      if (autocompleteControllers.user) {
        autocompleteControllers.user.setSelection('', '');
      }
      if (autocompleteControllers.venue) {
        autocompleteControllers.venue.setSelection('', '');
      }
      setCurrentVenuePrice(null);
      setBookingAddonsAvailability(false, null);
    }

    modalTitle.textContent =
      mode === 'edit' ? `Edit ${sectionConfig[section].title.slice(0, -1)}` : `Add ${sectionConfig[section].title.slice(0, -1)}`;
    if (submitLabel) {
      submitLabel.textContent = mode === 'edit' ? 'Update' : 'Create';
    }

    if (section === 'bookings') {
      updateBookingSubtotalDisplay();
    }

    showModalBackdrop();

    if (canAnimate && modalElement) {
      if (modalAnimation) {
        modalAnimation.pause();
        modalAnimation = null;
      }
      anime.remove([modalBackdrop, modalElement]);
      anime.set(modalBackdrop, { opacity: 0 });
      anime.set(modalElement, { opacity: 0, translateY: 22, scale: 0.96 });
      modalAnimation = anime
        .timeline({
          duration: 280,
          easing: 'easeOutQuad',
          complete: () => {
            resetModalStyles();
            modalAnimation = null;
          },
        })
        .add({
          targets: modalBackdrop,
          opacity: 1,
          duration: 180,
        })
        .add(
          {
            targets: modalElement,
            opacity: 1,
            translateY: 0,
            scale: 1,
            duration: 280,
          },
          '-=120'
        );
    } else {
      resetModalStyles();
    }
  }

  function closeModal() {
    state.editingId = null;
    closeAllAutocompletes();
    if (!modalBackdrop) {
      return;
    }
    if (modalBackdrop.hidden) {
      hideModalBackdrop();
      resetModalStyles();
      return;
    }
    if (!canAnimate || !modalElement) {
      hideModalBackdrop();
      resetModalStyles();
      return;
    }

    if (modalAnimation) {
      modalAnimation.pause();
      modalAnimation = null;
    }
    anime.remove([modalBackdrop, modalElement]);
    modalAnimation = anime
      .timeline({
        duration: 220,
        easing: 'easeInOutQuad',
        complete: () => {
          hideModalBackdrop();
          resetModalStyles();
          modalAnimation = null;
        },
      })
      .add({
        targets: modalElement,
        opacity: 0,
        translateY: 16,
        scale: 0.96,
        duration: 200,
      })
      .add(
        {
          targets: modalBackdrop,
          opacity: 0,
          duration: 160,
        },
        '-=120'
      );
  }

  async function loadSection(section, options = {}) {
    const endpoint = endpoints[section];
    if (!endpoint || !endpoint.list) {
      return null;
    }

    const currentMeta = state.pagination[section] || {};
    const query = options.query !== undefined ? options.query : state.search[section] || '';
    const requestedPageSize = options.pageSize !== undefined ? Number(options.pageSize) : currentMeta.pageSize;
    const pageSize = Number.isFinite(requestedPageSize) && requestedPageSize > 0 ? requestedPageSize : DEFAULT_PAGE_SIZE;
    const requestedPage = options.page !== undefined ? Number(options.page) : currentMeta.page;
    const page = Number.isFinite(requestedPage) && requestedPage > 0 ? requestedPage : 1;

    const params = new URLSearchParams();
    params.set('page', String(page));
    params.set('page_size', String(pageSize));
    if (query) {
      params.set('q', query);
    }

    if (fetchControllers[section]) {
      fetchControllers[section].abort();
    }
    const controller = new AbortController();
    fetchControllers[section] = controller;

    try {
      setLoading(section, true);
      const response = await fetch(`${endpoint.list}?${params.toString()}`, {
        headers: { 'X-Requested-With': 'XMLHttpRequest' },
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new Error('Failed to load data');
      }
      const payload = await response.json();
      if (!payload.success) {
        return null;
      }
      const data = Array.isArray(payload.data) ? payload.data : [];
      const meta = normalizePaginationMeta(payload.meta, {
        page,
        pageSize,
        query,
        totalItems: currentMeta.totalItems,
        totalPages: currentMeta.totalPages,
        hasPrevious: currentMeta.hasPrevious,
        hasNext: currentMeta.hasNext,
      });

      state[section] = data;
      state.pagination[section] = meta;
      state.search[section] = meta.query || '';

      if (searchInputs[section] && searchInputs[section].value !== state.search[section]) {
        searchInputs[section].value = state.search[section];
      }

      if (section === 'bookings' && typeof meta.has_users === 'boolean') {
        state.hasUsers = meta.has_users;
      }

      if (section === 'venues') {
        renderVenues();
        syncVenueAutocompleteSelection();
        if (autocompleteControllers.venue) {
          if (!state.venues.length && !meta.totalItems) {
            autocompleteControllers.venue.clear();
          } else {
            autocompleteControllers.venue.refresh();
          }
        }
        if (state.currentSection === 'bookings') {
          renderBookings();
        }
      } else if (section === 'bookings') {
        renderBookings();
        updateAnalytics(meta.analytics || (payload.meta ? payload.meta.analytics : undefined));
      }

      updateActionButton();
      return payload;
    } catch (error) {
      if (error.name === 'AbortError') {
        return null;
      }
      console.error(error);
      showToast('Unable to load data right now.');
      return null;
    } finally {
      setLoading(section, false);
      if (fetchControllers[section] === controller) {
        fetchControllers[section] = null;
      }
    }
  }

  async function refreshFromServer(section, options = {}) {
    return loadSection(section, options);
  }

  async function handleFormSubmit(event) {
    event.preventDefault();
    const section = entityForm.dataset.section;
    const mode = entityForm.dataset.mode;
    const recordId = entityForm.dataset.recordId;

    const endpoint = endpoints[section];
    if (!endpoint) {
      return;
    }

    const url = mode === 'edit' ? endpoint.update(recordId) : endpoint.create;
    syncAddonsInput();
    const formData = new FormData(entityForm);

    if (section === 'venues') {
      const imageField = entityForm.querySelector('input[name="image"]');
      if (imageField && imageField.files && imageField.files.length === 0) {
        formData.delete('image');
      }
    }

    if (section === 'bookings' && !entityForm.querySelector('input[name="has_been_paid"]').checked) {
      formData.delete('has_been_paid');
    }

    const submitButton = entityForm.querySelector('button[type="submit"]');
    clearErrors();

    if (section === 'bookings') {
      const venueId = formData.get('venue');
      if (!venueId) {
        showErrors(['Please choose a venue from the list.']);
        if (autocompleteControllers.venue && autocompleteControllers.venue.input) {
          autocompleteControllers.venue.input.focus();
        }
        return;
      }
    }

    submitButton.disabled = true;
    submitButton.classList.add('is-loading');

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'X-CSRFToken': getCsrfToken(),
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: formData,
      });

      const payload = await response.json();
      if (!response.ok || !payload.success) {
        const errors = payload && payload.errors ? payload.errors : ['Unable to save changes.'];
        showErrors(errors);
        return;
      }

      if (section === 'venues') {
        if (
          mode === 'edit' &&
          autocompleteControllers.venue &&
          autocompleteControllers.venue.hiddenInput &&
          Number(autocompleteControllers.venue.hiddenInput.value) === Number(payload.data.id)
        ) {
          autocompleteControllers.venue.setSelection(payload.data.title || '', payload.data.id);
        }

        const targetPage = mode === 'edit' ? state.pagination.venues.page || 1 : 1;
        await refreshFromServer('venues', {
          page: targetPage,
          query: state.search.venues || '',
        });

        if (mode === 'edit') {
          await refreshFromServer('bookings', {
            page: state.pagination.bookings.page || 1,
            query: state.search.bookings || '',
          });
        }
      } else if (section === 'bookings') {
        state.hasUsers = true;
        const targetPage = mode === 'edit' ? state.pagination.bookings.page || 1 : 1;
        await refreshFromServer('bookings', {
          page: targetPage,
          query: state.search.bookings || '',
        });
      }

      closeModal();
      showToast(mode === 'edit' ? 'Updated successfully!' : 'Created successfully!');
    } catch (error) {
      console.error(error);
      showErrors(['Network error. Please try again.']);
    } finally {
      submitButton.disabled = false;
      submitButton.classList.remove('is-loading');
    }
  }

  async function handleDelete(section, recordId) {
    const endpoint = endpoints[section];
    if (!endpoint) {
      return;
    }
    const confirmed = window.confirm('Are you sure you want to delete this item?');
    if (!confirmed) {
      return;
    }
    try {
      const response = await fetch(endpoint.delete(recordId), {
        method: 'POST',
        headers: {
          'X-CSRFToken': getCsrfToken(),
          'X-Requested-With': 'XMLHttpRequest',
        },
      });
      const payload = await response.json();
      if (!response.ok || !payload.success) {
        throw new Error('Delete failed');
      }
      await animateRowRemoval(section, recordId);
      if (section === 'venues') {
        if (
          autocompleteControllers.venue
          && autocompleteControllers.venue.hiddenInput
          && Number(autocompleteControllers.venue.hiddenInput.value) === Number(recordId)
        ) {
          autocompleteControllers.venue.clear();
        }
        await refreshFromServer('venues', {
          page: state.pagination.venues.page || 1,
          query: state.search.venues || '',
        });
        await refreshFromServer('bookings', {
          page: state.pagination.bookings.page || 1,
          query: state.search.bookings || '',
        });
      } else if (section === 'bookings') {
        await refreshFromServer('bookings', {
          page: state.pagination.bookings.page || 1,
          query: state.search.bookings || '',
        });
      }
      showToast('Deleted successfully.');
    } catch (error) {
      console.error(error);
      showToast('Unable to delete this item right now.');
    }
  }

  navButtons.forEach((button) => {
    button.addEventListener('click', () => {
      setActiveSection(button.dataset.target);
    });
  });

  actionButton.addEventListener('click', () => {
    openModal('create', state.currentSection);
  });

  entityForm.addEventListener('submit', handleFormSubmit);

  const bookingStartInput = entityForm.querySelector('input[name="start_date"]');
  const bookingEndInput = entityForm.querySelector('input[name="end_date"]');
  if (bookingStartInput && bookingEndInput) {
    ['change', 'input'].forEach((eventName) => {
      bookingStartInput.addEventListener(eventName, updateBookingSubtotalDisplay);
      bookingEndInput.addEventListener(eventName, updateBookingSubtotalDisplay);
    });
  }

  document.querySelectorAll('[data-action="close-modal"]').forEach((button) => {
    button.addEventListener('click', () => {
      closeModal();
    });
  });

  if (modalBackdrop) {
    modalBackdrop.addEventListener('click', (event) => {
      if (event.target === modalBackdrop) {
        closeModal();
      }
    });
  }

  venuesTableBody.addEventListener('click', (event) => {
    const button = event.target.closest('button');
    if (!button) {
      return;
    }
    if (button.dataset.action === 'edit') {
      openModal('edit', 'venues', button.dataset.id);
    } else if (button.dataset.action === 'delete') {
      handleDelete('venues', button.dataset.id);
    }
  });

  bookingsTableBody.addEventListener('click', (event) => {
    const button = event.target.closest('button');
    if (!button) {
      return;
    }
    if (button.dataset.action === 'edit') {
      openModal('edit', 'bookings', button.dataset.id);
    } else if (button.dataset.action === 'delete') {
      handleDelete('bookings', button.dataset.id);
    }
  });

  document.addEventListener('click', async (event) => {
    const refreshButton = event.target.closest('[data-action="refresh-bookings"]');
    if (!refreshButton) {
      return;
    }
    await refreshFromServer('bookings', {
      page: state.pagination.bookings.page || 1,
      query: state.search.bookings || '',
    });
  });

  Object.entries(searchInputs).forEach(([section, input]) => {
    if (!input) {
      return;
    }
    input.value = state.search[section] || '';
    if (section === 'venues' || section === 'bookings') {
      input.addEventListener('keydown', (event) => {
        if (event.key !== 'Enter') {
          return;
        }
        event.preventDefault();
        handleSearchChange(section, event.target.value);
      });
    } else {
      input.addEventListener('keyup', (event) => {
        handleSearchChange(section, event.target.value);
      });
    }
    input.addEventListener('search', (event) => {
      if (section === 'venues' || section === 'bookings') {
        const value = typeof event.target.value === 'string' ? event.target.value.trim() : '';
        if (value) {
          return;
        }
      }
      handleSearchChange(section, event.target.value);
    });
  });

  const venueSearchButton = document.querySelector('[data-action="search-venues"]');
  const venueSearchInput = searchInputs.venues;
  if (venueSearchButton && venueSearchInput) {
    venueSearchButton.addEventListener('click', () => {
      handleSearchChange('venues', venueSearchInput.value);
    });
  }

  const bookingSearchButton = document.querySelector('[data-action="search-bookings"]');
  const bookingSearchInput = searchInputs.bookings;
  if (bookingSearchButton && bookingSearchInput) {
    bookingSearchButton.addEventListener('click', () => {
      handleSearchChange('bookings', bookingSearchInput.value);
    });
  }

  registerSidebarToggle();
  registerSorting();
  initializeCharts();
  renderVenues();
  renderBookings();
  updateHeader(state.currentSection);
  updateActionButton();
  refreshFromServer('venues');
})();
