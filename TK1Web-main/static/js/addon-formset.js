(function () {
  const onReady = (callback) => {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', callback, { once: true });
    } else {
      callback();
    }
  };

  const parseHTML = (html) => {
    const wrapper = document.createElement('div');
    wrapper.innerHTML = html.trim();
    return wrapper.firstElementChild;
  };

  const applyRemovalState = (formElement, deleteInput, removeButton, isRemoved) => {
    if (deleteInput) {
      deleteInput.checked = isRemoved;
    }
    formElement.dataset.addonRemoved = isRemoved ? 'true' : 'false';
    formElement.classList.toggle('opacity-50', isRemoved);
    formElement.classList.toggle('border-rose-300/40', isRemoved);
    if (removeButton) {
      const removeLabel = removeButton.dataset.removeLabel || 'Remove add-on';
      const restoreLabel = removeButton.dataset.restoreLabel || 'Undo removal';
      removeButton.textContent = isRemoved ? restoreLabel : removeLabel;
    }
  };

  onReady(() => {
    document.querySelectorAll('[data-addon-formset]').forEach((formsetElement) => {
      const formsContainer = formsetElement.querySelector('[data-addon-forms]');
      const totalInput = formsetElement.querySelector('input[name$="-TOTAL_FORMS"]');
      const addButton = formsetElement.querySelector('[data-addon-add]');
      const template = formsetElement.querySelector('template[data-addon-empty-form]');

      if (!formsContainer || !totalInput || !template) {
        if (addButton) {
          addButton.setAttribute('disabled', 'true');
        }
        return;
      }

      const templateHTML = template.innerHTML.trim();
      if (!templateHTML) {
        if (addButton) {
          addButton.setAttribute('disabled', 'true');
        }
        return;
      }

      const initialiseForm = (formElement) => {
        const deleteInput = formElement.querySelector('[data-addon-delete-input]');
        const removeButton = formElement.querySelector('[data-addon-remove]');

        if (removeButton) {
          removeButton.addEventListener('click', (event) => {
            event.preventDefault();
            const currentlyRemoved = formElement.dataset.addonRemoved === 'true';
            applyRemovalState(formElement, deleteInput, removeButton, !currentlyRemoved);
          });
        }

        const isRemoved = deleteInput ? deleteInput.checked : false;
        applyRemovalState(formElement, deleteInput, removeButton, isRemoved);
      };

      const addNewForm = () => {
        const currentTotal = parseInt(totalInput.value, 10) || 0;
        const newFormHTML = templateHTML.replace(/__prefix__/g, String(currentTotal));
        const newFormElement = parseHTML(newFormHTML);
        if (!newFormElement) {
          return;
        }
        formsContainer.appendChild(newFormElement);
        totalInput.value = String(currentTotal + 1);
        initialiseForm(newFormElement);
      };

      if (addButton) {
        addButton.addEventListener('click', (event) => {
          event.preventDefault();
          addNewForm();
        });
      }

      formsContainer.querySelectorAll('[data-addon-form]').forEach((formElement) => {
        initialiseForm(formElement);
      });
    });
  });
})();
