(function () {
  if (typeof onDocumentReady !== 'function') {
    return;
  }

  const buildDetailUrl = (template, id) => {
    if (!template) {
      return '';
    }
    if (!id && id !== 0) {
      return template;
    }
    const stringId = String(id);
    if (template.endsWith('/0/') || template.endsWith('/0')) {
      return template.replace(/0\/?$/, `${stringId}/`);
    }
    return `${template.replace(/\/?$/, '')}/${stringId}/`;
  };

  const openModalById = (modalId) => {
    const modal = document.getElementById(modalId);
    if (!modal) {
      return;
    }
    const opener = document.createElement('button');
    opener.type = 'button';
    opener.dataset.modalTarget = modalId;
    opener.hidden = true;
    document.body.appendChild(opener);
    opener.click();
    opener.remove();
  };

  const normaliseErrors = (errors) => {
    if (!errors || typeof errors !== 'object') {
      return {};
    }
    const normalised = {};
    Object.entries(errors).forEach(([field, messages]) => {
      if (Array.isArray(messages)) {
        normalised[field] = messages.map((message) => String(message));
      } else if (messages && typeof messages === 'object') {
        const list = Array.isArray(messages.messages) ? messages.messages : Object.values(messages);
        normalised[field] = list.map((message) => String(message));
      } else if (messages) {
        normalised[field] = [String(messages)];
      }
    });
    return normalised;
  };

  onDocumentReady(() => {
    const appRoot = document.querySelector('[data-admin-venue-app]');
    if (!appRoot) {
      return;
    }

    const listUrl = appRoot.dataset.venuesApiUrl || '';
    const detailTemplate = appRoot.dataset.venueDetailUrlTemplate || '';
    const modalId = appRoot.dataset.venueModalId || 'admin-venue-modal';
    const modal = document.getElementById(modalId);
    const form = modal ? modal.querySelector('[data-venue-form]') : null;
    const formTitle = modal ? modal.querySelector('[data-venue-modal-title]') : null;
    const submitButton = modal ? modal.querySelector('[data-venue-submit]') : null;
    const formErrorContainer = modal ? modal.querySelector('[data-form-error]') : null;
    const tableBody = appRoot.querySelector('[data-venue-table-body]');
    const csrfToken = typeof getCsrfToken === 'function' ? getCsrfToken() : '';
    const addonFormsetElement = form ? form.querySelector('[data-addon-formset]') : null;

    const addonControls = addonFormsetElement
      ? {
          formsContainer: addonFormsetElement.querySelector('[data-addon-forms]'),
          addButton: addonFormsetElement.querySelector('[data-addon-add]'),
          totalInput: addonFormsetElement.querySelector('input[name$="-TOTAL_FORMS"]'),
          initialInput: addonFormsetElement.querySelector('input[name$="-INITIAL_FORMS"]'),
        }
      : null;

    if (!listUrl || !detailTemplate || !modal || !form || !tableBody) {
      return;
    }

    let venuesCache = new Map();
    let isFetching = false;

    const clearFormErrors = () => {
      if (formErrorContainer) {
        formErrorContainer.textContent = '';
        formErrorContainer.classList.add('hidden');
      }
      form.querySelectorAll('[data-field-error]').forEach((element) => {
        element.textContent = '';
        element.classList.add('hidden');
      });
      form.querySelectorAll('[aria-invalid="true"]').forEach((element) => {
        element.setAttribute('aria-invalid', 'false');
      });
    };

    const resetAddonFormset = () => {
      if (!addonControls) {
        return;
      }
      const { formsContainer, totalInput, initialInput } = addonControls;
      if (formsContainer) {
        formsContainer.innerHTML = '';
      }
      if (totalInput) {
        totalInput.value = '0';
      }
      if (initialInput) {
        initialInput.value = '0';
      }
    };

    const createAddonFormElement = () => {
      if (!addonControls) {
        return null;
      }
      const { formsContainer, addButton } = addonControls;
      if (!formsContainer || !addButton) {
        return null;
      }
      const existing = Array.from(formsContainer.querySelectorAll('[data-addon-form]'));
      addButton.click();
      const updated = Array.from(formsContainer.querySelectorAll('[data-addon-form]'));
      const added = updated.find((element) => !existing.includes(element));
      return added || updated[updated.length - 1] || null;
    };

    const populateAddonFormset = (addons, venueId) => {
      if (!addonControls) {
        return;
      }
      resetAddonFormset();
      if (!Array.isArray(addons) || addons.length === 0) {
        return;
      }
      const { formsContainer, initialInput, totalInput } = addonControls;
      addons.forEach((addon) => {
        const formElement = createAddonFormElement();
        if (!formElement) {
          return;
        }
        const setInputValue = (selector, value) => {
          const input = formElement.querySelector(selector);
          if (!input) {
            return;
          }
          if (input.type === 'checkbox') {
            input.checked = Boolean(value);
          } else {
            input.value = value == null ? '' : value;
          }
        };
        setInputValue('input[name$="-id"]', addon.id || '');
        if (venueId) {
          setInputValue('input[name$="-venue"]', venueId);
        }
        setInputValue('input[name$="-name"]', addon.name || '');
        setInputValue('textarea[name$="-description"]', addon.description || '');
        setInputValue('input[name$="-price"]', addon.price != null ? addon.price : '');
        const deleteInput = formElement.querySelector('[data-addon-delete-input]');
        if (deleteInput) {
          deleteInput.checked = false;
        }
        formElement.dataset.addonRemoved = 'false';
      });
      if (initialInput) {
        initialInput.value = String(addons.length);
      }
      if (totalInput) {
        const totalForms = formsContainer
          ? formsContainer.querySelectorAll('[data-addon-form]').length
          : addons.length;
        totalInput.value = String(totalForms);
      }
    };

    const setFormErrors = (errors) => {
      clearFormErrors();
      const normalised = normaliseErrors(errors);
      Object.entries(normalised).forEach(([field, messages]) => {
        const message = messages.join('\n');
        if (field === '__all__') {
          if (formErrorContainer) {
            formErrorContainer.textContent = message;
            formErrorContainer.classList.remove('hidden');
          }
          return;
        }
        const fieldError = form.querySelector(`[data-field-error="${field}"]`);
        if (fieldError) {
          fieldError.textContent = message;
          fieldError.classList.remove('hidden');
        }
        const input = form.querySelector(`[name="${CSS.escape(field)}"]`);
        if (input) {
          input.setAttribute('aria-invalid', 'true');
        }
      });
    };

    const resetForm = () => {
      form.reset();
      resetAddonFormset();
      clearFormErrors();
      delete form.dataset.mode;
      delete form.dataset.venueId;
    };

    const populateForm = (venue) => {
      if (!venue) {
        return;
      }
      const entries = {
        category: venue.category ? venue.category.id : '',
        name: venue.name || '',
        slug: venue.slug || '',
        description: venue.description || '',
        location: venue.location || '',
        city: venue.city || '',
        address: venue.address || '',
        price_per_hour: venue.price_per_hour || '',
        capacity: venue.capacity || '',
        facilities: venue.facilities || '',
        image_url: venue.image_url || '',
        available_start_time: venue.available_start_time || '',
        available_end_time: venue.available_end_time || '',
      };
      Object.entries(entries).forEach(([field, value]) => {
        const input = form.querySelector(`[name="${CSS.escape(field)}"]`);
        if (!input) {
          return;
        }
        if (input.type === 'checkbox') {
          input.checked = Boolean(value);
        } else {
          input.value = value == null ? '' : value;
        }
      });
      const addons = Array.isArray(venue.addons) ? venue.addons : [];
      populateAddonFormset(addons, venue.id);
    };

    const renderVenueRow = (venue) => {
      const safeName = escapeHtml(venue.name);
      const safeCity = escapeHtml(venue.city);
      const safeCategory = escapeHtml(venue.category ? venue.category.name : '');
      const safePrice = venue.price_per_hour ? formatCurrency(venue.price_per_hour) : '';
      const viewUrl = escapeHtml(venue.detail_url || '#');
      const editUrl = escapeHtml(venue.edit_url || '#');
      const deleteUrl = escapeHtml(venue.delete_url || '#');
      const id = escapeHtml(venue.id);
      return `
        <tr class="hover:bg-white/5" data-venue-row data-venue-id="${id}">
          <td class="px-6 py-4 font-semibold text-white">${safeName}</td>
          <td class="px-6 py-4">${safeCity}</td>
          <td class="px-6 py-4">${safeCategory}</td>
          <td class="px-6 py-4">Rp ${safePrice}</td>
          <td class="px-6 py-4">
            <div class="flex flex-wrap gap-2">
              <a href="${viewUrl}" class="rounded-xl border border-white/20 px-3 py-1 text-xs text-white transition hover:bg-white/10">View</a>
              <a href="${editUrl}" data-admin-venue-edit data-modal-target="${modalId}" data-venue-id="${id}" class="rounded-xl border border-white/20 px-3 py-1 text-xs text-white transition hover:bg-white/10">Edit</a>
              <form method="post" action="${deleteUrl}" class="inline" data-admin-venue-delete data-venue-id="${id}">
                <input type="hidden" name="csrfmiddlewaretoken" value="${escapeHtml(csrfToken)}" />
                <button type="submit" class="rounded-xl border border-rose-300/40 px-3 py-1 text-xs text-rose-200 transition hover:bg-rose-400/20">Delete</button>
              </form>
            </div>
          </td>
        </tr>
      `;
    };

    const renderEmptyRow = () => {
      return `
        <tr>
          <td colspan="5" class="px-6 py-6 text-center text-white/70">No venues available yet.</td>
        </tr>
      `;
    };

    const renderVenues = (venues) => {
      if (!Array.isArray(venues) || venues.length === 0) {
        tableBody.innerHTML = renderEmptyRow();
        return;
      }
      const rows = venues.map((venue) => renderVenueRow(venue)).join('');
      tableBody.innerHTML = rows;
    };

    const refreshVenues = async () => {
      if (isFetching) {
        return;
      }
      isFetching = true;
      try {
        const response = await fetch(listUrl, {
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
          },
          credentials: 'same-origin',
        });
        if (!response.ok) {
          throw new Error('Failed to fetch venues');
        }
        const payload = await response.json();
        if (!payload || payload.success !== true || !Array.isArray(payload.venues)) {
          throw new Error('Invalid venue payload');
        }
        venuesCache = new Map(payload.venues.map((venue) => [String(venue.id), venue]));
        renderVenues(payload.venues);
      } catch (error) {
        console.error(error);
        showToast('Tidak dapat memuat data venue. Coba lagi nanti.', { level: 'error' });
      } finally {
        isFetching = false;
      }
    };

    const buildRequestPayload = () => {
      const formData = new FormData(form);
      const payload = {};
      for (const [key, value] of formData.entries()) {
        if (typeof value === 'string') {
          payload[key] = value.trim();
        } else {
          payload[key] = value;
        }
      }
      return payload;
    };

    const submitVenueForm = async () => {
      const mode = form.dataset.mode || 'create';
      const isEdit = mode === 'edit';
      const venueId = form.dataset.venueId;
      const targetUrl = isEdit ? buildDetailUrl(detailTemplate, venueId) : listUrl;
      const method = isEdit ? 'PUT' : 'POST';
      if (!targetUrl) {
        return;
      }
      if (submitButton) {
        submitButton.setAttribute('disabled', 'true');
      }
      form.dataset.submitting = 'true';
      clearFormErrors();
      try {
        const response = await fetch(targetUrl, {
          method,
          headers: {
            'Content-Type': 'application/json',
            'X-CSRFToken': csrfToken,
            'X-Requested-With': 'XMLHttpRequest',
          },
          credentials: 'same-origin',
          body: JSON.stringify(buildRequestPayload()),
        });
        const payload = await response.json().catch(() => null);
        if (!response.ok || !payload) {
          throw payload;
        }
        if (payload.success !== true || !payload.venue) {
          throw payload;
        }
        const message = isEdit ? 'Venue updated successfully.' : 'Venue created successfully.';
        showToast(message, { level: 'success' });
        closeContainingModal(form);
        resetForm();
        await refreshVenues();
      } catch (error) {
        const errors = error && error.errors ? error.errors : null;
        if (errors) {
          setFormErrors(errors);
        } else {
          showToast('Tidak dapat menyimpan data venue. Periksa formulir Anda.', { level: 'error' });
        }
      } finally {
        delete form.dataset.submitting;
        if (submitButton) {
          submitButton.removeAttribute('disabled');
        }
      }
    };

    form.addEventListener('submit', (event) => {
      event.preventDefault();
      if (form.dataset.submitting === 'true') {
        return;
      }
      submitVenueForm();
    });

    const handleCreateClick = (event) => {
      event.preventDefault();
      resetForm();
      form.dataset.mode = 'create';
      if (formTitle) {
        formTitle.textContent = 'Add new venue';
      }
      if (submitButton) {
        submitButton.textContent = 'Create venue';
      }
      openModalById(modalId);
    };

    const handleEditClick = (event) => {
      const trigger = event.target.closest('[data-admin-venue-edit]');
      if (!trigger) {
        return;
      }
      event.preventDefault();
      const venueId = trigger.getAttribute('data-venue-id');
      if (!venueId || !venuesCache.has(venueId)) {
        showToast('Data venue tidak ditemukan.', { level: 'error' });
        return;
      }
      const venue = venuesCache.get(venueId);
      resetForm();
      form.dataset.mode = 'edit';
      form.dataset.venueId = venueId;
      populateForm(venue);
      if (formTitle) {
        formTitle.textContent = `Edit venue • ${venue.name}`;
      }
      if (submitButton) {
        submitButton.textContent = 'Update venue';
      }
      openModalById(modalId);
    };

    const handleDeleteSubmit = async (event) => {
      const formElement = event.target.closest('[data-admin-venue-delete]');
      if (!formElement) {
        return;
      }
      event.preventDefault();
      if (formElement.dataset.deleting === 'true') {
        return;
      }
      const venueId = formElement.getAttribute('data-venue-id');
      if (!venueId) {
        return;
      }
      const confirmed = window.confirm('Are you sure you want to delete this venue?');
      if (!confirmed) {
        return;
      }
      formElement.dataset.deleting = 'true';
      const deleteUrl = buildDetailUrl(detailTemplate, venueId);
      try {
        const response = await fetch(deleteUrl, {
          method: 'DELETE',
          headers: {
            'X-CSRFToken': csrfToken,
            'X-Requested-With': 'XMLHttpRequest',
          },
          credentials: 'same-origin',
        });
        const payload = await response.json().catch(() => null);
        if (!response.ok || !payload || payload.success !== true) {
          throw new Error('Delete failed');
        }
        showToast('Venue deleted successfully.', { level: 'success' });
        await refreshVenues();
      } catch (error) {
        console.error(error);
        showToast('Tidak dapat menghapus venue saat ini.', { level: 'error' });
      } finally {
        delete formElement.dataset.deleting;
      }
    };

    document.addEventListener('click', (event) => {
      if (event.target.matches('[data-venue-create]')) {
        handleCreateClick(event);
        return;
      }
      if (event.target.closest('[data-admin-venue-edit]')) {
        handleEditClick(event);
      }
    });

    document.addEventListener('submit', (event) => {
      if (event.target.closest('[data-admin-venue-delete]')) {
        handleDeleteSubmit(event);
      }
    });

    refreshVenues();
  });
})();
