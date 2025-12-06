(function () {
  const getCookie = (name) => {
    if (typeof document === 'undefined') {
      return '';
    }
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) {
      return parts.pop().split(';').shift();
    }
    return '';
  };

  const getCsrfToken = () => {
    const cookieToken = getCookie('csrftoken');
    if (cookieToken) {
      return cookieToken;
    }
    const meta = document.querySelector('meta[name="csrf-token"]');
    if (meta) {
      return meta.getAttribute('content') || '';
    }
    return '';
  };

  const toggleHidden = (element, shouldHide) => {
    if (!element) {
      return;
    }
    element.classList.toggle('hidden', Boolean(shouldHide));
  };

  const renderFieldErrors = (form, errors) => {
    if (!form) {
      return;
    }
    const elements = form.querySelectorAll('[data-field-error]');
    elements.forEach((node) => {
      toggleHidden(node, true);
      node.textContent = '';
    });

    if (!errors || typeof errors !== 'object') {
      return;
    }

    Object.entries(errors).forEach(([field, messages]) => {
      const target = form.querySelector(`[data-field-error="${field}"]`);
      if (!target) {
        return;
      }
      const fieldMessages = Array.isArray(messages) ? messages : [messages];
      target.innerHTML = '';
      fieldMessages
        .filter((message) => Boolean(message))
        .forEach((message) => {
          const paragraph = document.createElement('p');
          paragraph.textContent = message;
          target.appendChild(paragraph);
        });
      toggleHidden(target, target.childElementCount === 0);
    });
  };

  const showFeedback = (element, message, type = 'error') => {
    if (!element) {
      return;
    }
    const trimmedMessage = typeof message === 'string' ? message.trim() : '';
    if (!trimmedMessage) {
      element.textContent = '';
      toggleHidden(element, true);
      element.removeAttribute('data-feedback-state');
      return;
    }

    element.innerHTML = '';
    const paragraph = document.createElement('p');
    paragraph.textContent = trimmedMessage;
    element.appendChild(paragraph);

    const baseClasses = [
      'rounded-2xl',
      'px-4',
      'py-3',
      'text-sm',
      'transition-all',
      'duration-150',
      'border',
    ];
    const typeClasses =
      type === 'success'
        ? ['border-emerald-400/40', 'bg-emerald-500/20', 'text-emerald-50']
        : ['border-rose-500/40', 'bg-rose-500/10', 'text-rose-100'];

    element.className = `${baseClasses.join(' ')} ${typeClasses.join(' ')}`;
    element.setAttribute('data-feedback-state', type);
    element.setAttribute('role', 'alert');
    toggleHidden(element, false);
  };

  const setSubmittingState = (form, isSubmitting) => {
    if (!form) {
      return;
    }
    const submitButton = form.querySelector('[data-login-submit]');
    const label = form.querySelector('[data-login-submit-label]');
    const spinner = form.querySelector('[data-login-submit-spinner]');

    if (submitButton) {
      submitButton.disabled = Boolean(isSubmitting);
      submitButton.classList.toggle('opacity-70', Boolean(isSubmitting));
      submitButton.classList.toggle('cursor-not-allowed', Boolean(isSubmitting));
    }

    if (label) {
      label.textContent = isSubmitting ? 'Please wait…' : 'Login';
    }

    toggleHidden(label, Boolean(isSubmitting));
    toggleHidden(spinner, !isSubmitting);
  };

  const attachLoginHandler = (form) => {
    if (!form) {
      return;
    }
    const feedback = form.querySelector('[data-login-feedback]');

    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      showFeedback(feedback, '');
      renderFieldErrors(form, {});
      setSubmittingState(form, true);

      const formData = new FormData(form);
      const requestConfig = {
        method: 'POST',
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRFToken': getCsrfToken(),
          Accept: 'application/json',
        },
        body: formData,
        credentials: 'same-origin',
      };

      try {
        const response = await fetch(form.action || window.location.href, requestConfig);
        const contentType = response.headers.get('content-type') || '';
        const isJson = contentType.includes('application/json');
        const payload = isJson ? await response.json() : null;

        if (!response.ok || !payload || payload.success === false) {
          const message = payload && Array.isArray(payload.non_field_errors) && payload.non_field_errors.length
            ? payload.non_field_errors.join(' ')
            : 'Unable to log you in with the provided credentials.';
          showFeedback(feedback, message, 'error');
          if (payload && payload.errors) {
            renderFieldErrors(form, payload.errors);
          }
          return;
        }

        if (payload && payload.success) {
          showFeedback(feedback, 'Successfully signed in. Redirecting…', 'success');
          const redirectUrl = payload.redirect_url || window.location.href;
          window.setTimeout(() => {
            window.location.assign(redirectUrl);
          }, 150);
        } else {
          showFeedback(feedback, 'Unexpected response received from the server.', 'error');
        }
      } catch (error) {
        showFeedback(
          feedback,
          'A network error occurred while attempting to sign you in. Please check your connection and try again.',
          'error'
        );
      } finally {
        setSubmittingState(form, false);
      }
    });
  };

  if (typeof document !== 'undefined') {
    const form = document.querySelector('[data-login-form]');
    if (form) {
      attachLoginHandler(form);
    }
  }
})();
